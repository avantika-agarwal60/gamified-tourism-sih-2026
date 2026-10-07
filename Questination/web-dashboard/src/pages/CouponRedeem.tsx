import { useState } from "react";
import { CheckCircle2, XCircle, TicketPercent } from "lucide-react";
import PageHeader from "../components/PageHeader";

const API_BASE = "https://questination-production-08b6.up.railway.app";

function CouponRedeem() {
  const [couponId, setCouponId] = useState("");
  const [otp, setOtp] = useState("");
  const [result, setResult] = useState<null | "success" | "fail">(null);
  const [loading, setLoading] = useState(false);

  async function handleConfirm() {
    setLoading(true);
    setResult(null);
    try {
      const response = await fetch(`${API_BASE}/api/coupons/redeem`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ coupon_id: couponId, otp }),
      });
      setResult(response.ok ? "success" : "fail");
    } catch {
      setResult("fail");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <PageHeader title="Verify Customer Coupon" subtitle="Enter the code your customer showed you to apply their discount." />
      <div className="bg-white p-8 rounded-2xl shadow-lg shadow-emerald-900/5 w-full max-w-md border border-amber-100">
        <div className="flex items-center gap-2 mb-4 text-emerald-700">
          <TicketPercent size={22} />
          <span className="font-semibold">Coupon Details</span>
        </div>

        <label className="block text-sm font-medium mb-1 text-gray-700">Coupon ID</label>
        <input type="text" placeholder="Enter coupon ID" value={couponId} onChange={(e) => setCouponId(e.target.value)}
          className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition" />

        <label className="block text-sm font-medium mb-1 text-gray-700">OTP</label>
        <input type="text" placeholder="Enter OTP" value={otp} onChange={(e) => setOtp(e.target.value)}
          className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-4 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition" />

        <button onClick={handleConfirm} disabled={loading}
          className="w-full bg-emerald-700 text-white py-3 rounded-lg font-medium hover:bg-emerald-800 transition shadow-md shadow-emerald-900/20 disabled:opacity-60">
          {loading ? "Verifying..." : "Confirm"}
        </button>

        {result === "success" && (
          <div className="mt-5 flex items-center gap-2 bg-green-50 text-green-700 px-4 py-3 rounded-lg">
            <CheckCircle2 size={20} /><span className="font-medium">Coupon redeemed successfully!</span>
          </div>
        )}
        {result === "fail" && (
          <div className="mt-5 flex items-center gap-2 bg-red-50 text-red-700 px-4 py-3 rounded-lg">
            <XCircle size={20} /><span className="font-medium">Invalid coupon or OTP.</span>
          </div>
        )}
      </div>
    </div>
  );
}

export default CouponRedeem;