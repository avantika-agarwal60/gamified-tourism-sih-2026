const prisma = require('../db/prismaClient.cjs');
const { generateOtp, sendOtp } = require('../services/otp-serivces.cjs');

// POST /api/coupons/generate
// Called when a user earns a coupon (quiz win or quest completion)
async function generateCoupon(req, res) {
  const { user_id, seller_id, discount_percent, source } = req.body;

  if (!user_id || !seller_id || !discount_percent || !source) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const otp = generateOtp();
    const expires_at = new Date(Date.now() + 48 * 60 * 60 * 1000); // expires in 48h

    const coupon = await prisma.coupons.create({
      data: { user_id, seller_id, discount_percent, source, otp, expires_at },
    });

    // Fetch the user's phone number to send the OTP to (assumes users table has a phone field)
    const user = await prisma.users.findUnique({ where: { id: user_id } });
    if (user?.phone) {
      await sendOtp(user.phone, otp);
    }

    res.status(201).json({ couponId: coupon.id, message: 'Coupon generated, OTP sent' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to generate coupon' });
  }
}

// POST /api/coupons/redeem
// Seller enters the OTP the customer shows them, at the point of sale
async function redeemCoupon(req, res) {
  const { coupon_id, otp } = req.body;

  try {
    const coupon = await prisma.coupons.findUnique({ where: { id: coupon_id } });

    if (!coupon) return res.status(404).json({ error: 'Coupon not found' });
    if (coupon.redeemed) return res.status(400).json({ error: 'Coupon already redeemed' });
    if (coupon.expires_at && new Date() > coupon.expires_at) {
      return res.status(400).json({ error: 'Coupon expired' });
    }
    if (coupon.otp !== otp) {
      return res.status(401).json({ error: 'Incorrect OTP' });
    }

    // Mark redeemed AND nullify the OTP — this is the "OTP nullification" step:
    // once used, the OTP can never be replayed to redeem it again.
    const updated = await prisma.coupons.update({
      where: { id: coupon_id },
      data: { redeemed: true, redeemed_at: new Date(), otp: null },
    });

    res.json({ message: 'Coupon redeemed successfully', coupon: updated });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to redeem coupon' });
  }
}

module.exports = { generateCoupon, redeemCoupon };
