MARRAKECH STAY V5 — CHAT + APARTMENT FIX

1. This version uses the uploaded apartment(2).html as the visual/functional base.
2. apartment.html now loads the same Supabase apartments as index.html/marrakech-backoffice.html.
3. Booking creation goes to public.bookings, so marrakech-backoffice.html receives the reservation.
4. Client chat writes to public.messages in Supabase.
5. Admin chat reads the same public.messages table.
6. Realtime + 2.5s polling are enabled for reliability.
7. Run V5_SUPABASE_FIX.sql once in Supabase SQL Editor.
8. Admin must sign in through Supabase Auth and have profiles.is_admin=true.
9. Payment remains a test flow with a 4.5-second delay. Only last4/card type and billing metadata are stored; PAN/CVV/expiry are never stored.

TEST CHAT:
- Open apartment.html?id=1
- Open chat
- Send "TEST CHAT 123"
- In marrakech-backoffice.html, sign in as the admin Supabase user
- Open Chat support
- Client should appear automatically.
- Reply from admin; client receives it within realtime/polling.

TEST BOOKING:
- Select dates
- Click Réserver maintenant
- The reservation is created in Supabase before the payment form appears.
- It should appear in Admin > Réservations.
