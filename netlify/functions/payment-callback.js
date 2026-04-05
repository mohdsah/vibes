// netlify/functions/payment-callback.js
// ToyyibPay akan call URL ini selepas payment berjaya/gagal
// AUTO-CREDIT coins bila payment success

exports.handler = async (event) => {
  const headers = { 'Content-Type': 'application/json' };

  // ToyyibPay callback format (POST dengan form data)
  let params = {};
  if (event.httpMethod === 'POST') {
    // Parse form-encoded body
    const qs = require('querystring');
    params = qs.parse(event.body);
  } else if (event.httpMethod === 'GET') {
    params = event.queryStringParameters || {};
  }

  console.log('ToyyibPay callback received:', JSON.stringify(params));

  // ToyyibPay callback params:
  // billcode, order_id, transaction_id, billpaymentAmount, billpaymentStatus
  // billpaymentStatus: 1 = success, 2 = pending, 3 = fail

  const {
    billcode,
    order_id: topupId,
    transaction_id: transactionId,
    billpaymentAmount,
    billpaymentStatus,
    billpaymentInvoiceNo
  } = params;

  // Jika bukan success, ignore
  if (billpaymentStatus !== '1') {
    console.log('Payment not successful, status:', billpaymentStatus);
    return { statusCode: 200, headers, body: JSON.stringify({ received: true, action: 'skipped' }) };
  }

  if (!topupId) {
    console.error('No topupId in callback');
    return { statusCode: 400, headers, body: JSON.stringify({ error: 'No topupId' }) };
  }

  try {
    // 1. Fetch topup request
    const topupRes = await fetch(
      `${process.env.SUPABASE_URL}/rest/v1/topup_requests?id=eq.${topupId}&select=*`,
      {
        headers: {
          'apikey': process.env.SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_KEY}`
        }
      }
    );
    const topups = await topupRes.json();
    const topup = Array.isArray(topups) ? topups[0] : null;

    if (!topup) {
      console.error('Topup record not found:', topupId);
      return { statusCode: 404, headers, body: JSON.stringify({ error: 'Topup not found' }) };
    }

    // Prevent double-credit
    if (topup.status === 'approved') {
      console.log('Already processed:', topupId);
      return { statusCode: 200, headers, body: JSON.stringify({ received: true, action: 'already_processed' }) };
    }

    // 2. Approve topup (trigger akan auto-credit coins via DB trigger)
    await fetch(
      `${process.env.SUPABASE_URL}/rest/v1/topup_requests?id=eq.${topupId}`,
      {
        method: 'PATCH',
        headers: {
          'apikey': process.env.SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${process.env.SUPABASE_SERVICE_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          status: 'approved',
          payment_reference: transactionId || billcode,
          processed_at: new Date().toISOString()
        })
      }
    );

    console.log(`✅ Topup approved: ${topupId}, coins: ${topup.coins_amount}, user: ${topup.user_id}`);

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ received: true, action: 'credited', coins: topup.coins_amount })
    };

  } catch (err) {
    console.error('Callback error:', err);
    return { statusCode: 500, headers, body: JSON.stringify({ error: err.message }) };
  }
};
