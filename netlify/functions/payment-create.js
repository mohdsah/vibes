// netlify/functions/payment-create.js
// Dipanggil dari topup.html untuk buat bil ToyyibPay
// Deploy: Netlify akan auto-detect functions/ folder

const https = require('https');
const querystring = require('querystring');

// ⚠️ SET ini dalam Netlify Environment Variables:
// TOYYIBPAY_SECRET_KEY = secret key kau dari dashboard ToyyibPay
// TOYYIBPAY_CATEGORY_CODE = category code kau
// SUPABASE_URL = https://dbgtrsjlsqgsnfcldzyu.supabase.co
// SUPABASE_SERVICE_KEY = service_role key (bukan anon key)

exports.handler = async (event) => {
  // CORS headers
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json'
  };

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 200, headers, body: '' };
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers, body: JSON.stringify({ error: 'Method not allowed' }) };
  }

  try {
    const { userId, packageId, coins, priceMyr, username, email, packageName } = JSON.parse(event.body);

    if (!userId || !coins || !priceMyr) {
      return { statusCode: 400, headers, body: JSON.stringify({ error: 'Missing required fields' }) };
    }

    // Create topup_request record dulu (status: pending)
    const supabaseRes = await fetch(`${process.env.SUPABASE_URL}/rest/v1/topup_requests`, {
      method: 'POST',
      headers: {
        'apikey': process.env.SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      },
      body: JSON.stringify({
        user_id: userId,
        package_id: packageId,
        coins_amount: coins,
        price_myr: priceMyr,
        payment_method: 'toyyibpay',
        status: 'pending'
      })
    });

    const topupRecord = await supabaseRes.json();
    const topupId = Array.isArray(topupRecord) ? topupRecord[0]?.id : topupRecord?.id;

    if (!topupId) {
      throw new Error('Failed to create topup record');
    }

    // Create ToyyibPay bill
    const callbackUrl = `${process.env.URL || 'https://your-site.netlify.app'}/.netlify/functions/payment-callback`;
    const returnUrl = `${process.env.URL || 'https://your-site.netlify.app'}/topup.html?status=success&ref=${topupId}`;

    const billData = querystring.stringify({
      userSecretKey: process.env.TOYYIBPAY_SECRET_KEY,
      categoryCode: process.env.TOYYIBPAY_CATEGORY_CODE,
      billName: `VIBES TopUp - ${packageName}`,
      billDescription: `Top up ${coins} coins untuk @${username}`,
      billPriceSetting: 1,          // 1 = fixed price
      billPayorInfo: 1,             // 1 = require payer info
      billAmount: Math.round(priceMyr * 100), // dalam sen (RM 5.00 = 500)
      billReturnUrl: returnUrl,
      billCallbackUrl: callbackUrl,
      billExternalReferenceNo: topupId,  // kita guna topup_id sebagai reference
      billTo: username,
      billEmail: email || '',
      billPhone: '',
      billSplitPayment: 0,
      billSplitPaymentArgs: '',
      billPaymentChannel: 0,        // 0 = semua (FPX + card)
      billContentEmail: `Terima kasih! Coins akan dikreditkan selepas pembayaran disahkan.`,
      billChargeToCustomer: 1       // 1 = platform charge, bukan customer
    });

    // Call ToyyibPay API
    const toyyibRes = await postToToyyibPay('https://toyyibpay.com/index.php/api/createBill', billData);

    if (!toyyibRes || !toyyibRes[0]?.BillCode) {
      throw new Error('ToyyibPay API error: ' + JSON.stringify(toyyibRes));
    }

    const billCode = toyyibRes[0].BillCode;
    const paymentUrl = `https://toyyibpay.com/${billCode}`;

    // Save billCode to topup record
    await fetch(`${process.env.SUPABASE_URL}/rest/v1/topup_requests?id=eq.${topupId}`, {
      method: 'PATCH',
      headers: {
        'apikey': process.env.SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ payment_reference: billCode })
    });

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ paymentUrl, billCode, topupId })
    };

  } catch (err) {
    console.error('payment-create error:', err);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: err.message })
    };
  }
};

// Helper: POST to ToyyibPay
function postToToyyibPay(url, data) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(data)
      }
    };
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch { resolve(body); }
      });
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}
