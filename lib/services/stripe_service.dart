// lib/services/stripe_service.dart
//
// ✅ BEZPEČNÁ VERZIA — secret key NIE je v klientskom kóde.
// Stripe PaymentIntent sa vytvára cez Firebase Cloud Function (createPaymentIntent).
// Táto trieda je len pomocný wrapper pre prípadné budúce utility.
//
// ❌ ODSTRÁNENÉ: priame volanie https://api.stripe.com/v1/payment_intents
//               s Bearer sk_live_... / sk_test_... — to je kritická bezpečnostná chyba.
//               Secret key nesmie byť nikdy v klientskej (Flutter) aplikácii.

class StripeService {
  // Platba prebieha v DepositPaymentScreen cez Firebase Cloud Function.
  // Secret key je uložený len v prostredí Firebase Functions (environment variable).
  //
  // Ako nastaviť secret key vo Firebase Functions:
  //   firebase functions:secrets:set STRIPE_SECRET_KEY
  //
  // Použitie v Node.js Firebase Function:
  //   const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);
}