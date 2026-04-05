# VIBES — Setup Real Payment (ToyyibPay)

## Langkah 1: Daftar ToyyibPay
1. Pergi https://toyyibpay.com
2. Register akaun business
3. Verify dengan dokumen syarikat/personal
4. Ambil **Secret Key** dan **Category Code** dari dashboard

## Langkah 2: Netlify Environment Variables
Pergi Netlify Dashboard → Site Settings → Environment Variables
Tambah:

```
TOYYIBPAY_SECRET_KEY    = [secret key dari ToyyibPay]
TOYYIBPAY_CATEGORY_CODE = [category code dari ToyyibPay]  
SUPABASE_URL            = https://dbgtrsjlsqgsnfcldzyu.supabase.co
SUPABASE_SERVICE_KEY    = [service_role key dari Supabase Settings]
URL                     = https://vibtok.netlify.app
```

⚠️ SUPABASE_SERVICE_KEY ada di: Supabase → Settings → API → service_role key
   BUKAN anon key. Service key ada full access.

## Langkah 3: Deploy
Push ke GitHub → Netlify auto-deploy
Functions akan deploy ke: https://vibtok.netlify.app/.netlify/functions/

## Langkah 4: Set Callback URL di ToyyibPay
ToyyibPay Dashboard → Settings → Callback URL:
```
https://vibtok.netlify.app/.netlify/functions/payment-callback
```

## Langkah 5: Update Bank Details dalam topup.html
Cari BANK_DETAILS dalam topup.html:
```javascript
const BANK_DETAILS = {
  bank: 'Maybank',           // ← tukar kepada bank kau
  account: '1234-5678-9012', // ← tukar kepada no. akaun kau
  holder: 'NAMA PENUH KAU'   // ← tukar kepada nama kau
};
```

## Flow Pembayaran Auto (ToyyibPay):
1. User pilih pakej → klik Bayar
2. Frontend call `/.netlify/functions/payment-create`
3. Function create topup_request (pending) + ToyyibPay bill
4. User redirect ke ToyyibPay payment page
5. User bayar via FPX/Kad
6. ToyyibPay call `/.netlify/functions/payment-callback`
7. Callback update topup_request → approved
8. DB trigger auto-credit coins
9. User dapat realtime notification

## Flow Manual (DuitNow):
1. User transfer ke bank details yang ditunjuk
2. Upload screenshot resit
3. Admin semak dalam admin panel → Approve
4. DB trigger auto-credit coins

## Withdraw Flow:
1. User isi borang (coins, bank, IC)
2. Sistem check tiada pending withdraw
3. Admin semak dalam admin panel
4. Admin verify IC + bank details
5. Admin transfer wang ke akaun user
6. Admin klik "✅ Lulus" → coins ditolak automatik
7. User dapat notification

## Test Mode ToyyibPay:
Guna sandbox: https://dev.toyyibpay.com (test cards ada dalam docs)
