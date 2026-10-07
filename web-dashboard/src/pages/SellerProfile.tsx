import { useState } from "react";
import { Store, CheckCircle2, IdCard, MapPin } from "lucide-react";
import PageHeader from "../components/PageHeader";
import { getUserId } from "../api/auth";
import { authFetch } from "../api/authFetch";

const API_BASE = "https://questination-production-08b6.up.railway.app";

async function readError(res: Response, fallback: string) {
  const data = await res.json().catch(() => ({}));
  return data.error ?? fallback;
}

function SellerProfile() {
  const [shopName, setShopName] = useState("");
  const [address, setAddress] = useState("");
  const [udyamId, setUdyamId] = useState("");
  const [idImage, setIdImage] = useState<File | null>(null);
  const [description, setDescription] = useState("");
  const [taxBracket, setTaxBracket] = useState("");
  const [saved, setSaved] = useState(false);
  const [submittedForReview, setSubmittedForReview] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSave() {
    setError("");
    setSaved(false);
    setSubmittedForReview(false);

    const userId = getUserId();
    if (!userId) {
      setError("Your session has expired. Please log in again.");
      return;
    }
    if (!shopName.trim()) {
      setError("Shop name is required.");
      return;
    }

    setLoading(true);
    try {
      const sellerUrl = `${API_BASE}/api/sellers/${encodeURIComponent(userId)}`;
      const body = JSON.stringify({
        userId,
        shop_name: shopName,
        description,
        tax_bracket_tier: taxBracket,
        address,
      });
      const jsonHeaders = { "Content-Type": "application/json" };

      // 1. Create the seller profile, or update it if it already exists
      const existing = await authFetch(sellerUrl);
      const profileRes = existing.ok
        ? await authFetch(sellerUrl, { method: "PUT", headers: jsonHeaders, body })
        : await authFetch(`${API_BASE}/api/sellers/register`, {
            method: "POST",
            headers: jsonHeaders,
            body,
          });

      if (!profileRes.ok) {
        throw new Error(await readError(profileRes, "Could not save your profile."));
      }

      // 2. Submit Udyam ID + photo. The backend marks the account as pending review.
      if (udyamId.trim() && idImage) {
        const form = new FormData();
        form.append("udyam_id", udyamId.trim());
        form.append("udyam_proof", idImage);

        // No Content-Type header here: the browser sets the multipart boundary itself
        const proofRes = await authFetch(`${sellerUrl}/udyam`, {
          method: "POST",
          body: form,
        });

        if (!proofRes.ok) {
          throw new Error(
            await readError(proofRes, "Profile saved, but the ID upload failed. Try again.")
          );
        }
        setSubmittedForReview(true);
      }

      setSaved(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong. Try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div>
      <PageHeader title="Seller Profile" subtitle="Set up your shop so tourists can find and support you." />
      <div className="bg-white p-8 rounded-2xl shadow-lg shadow-emerald-900/5 w-full max-w-md border border-amber-100">
        <div className="flex items-center gap-2 mb-4 text-emerald-700">
          <Store size={22} />
          <span className="font-semibold">Shop Details</span>
        </div>

        <label className="block text-sm font-medium mb-1 text-gray-700">Shop Name</label>
        <input
          type="text"
          value={shopName}
          onChange={(e) => setShopName(e.target.value)}
          className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
        />

        <div className="flex items-center gap-2 mb-1 text-gray-700">
          <MapPin size={16} />
          <label className="text-sm font-medium">Address</label>
        </div>
        <input
          type="text"
          value={address}
          onChange={(e) => setAddress(e.target.value)}
          className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
        />

        <div className="flex items-center gap-2 mb-1 text-gray-700">
          <IdCard size={16} />
          <label className="text-sm font-medium">Udyam / PEHCHAN ID</label>
        </div>
        <input
          type="text"
          value={udyamId}
          onChange={(e) => setUdyamId(e.target.value)}
          className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
        />

        <label className="block text-sm font-medium mb-1 text-gray-700">Upload ID Photo</label>
        <input
          type="file"
          accept="image/*"
          onChange={(e) => setIdImage(e.target.files?.[0] || null)}
          className="w-full text-sm mb-1"
        />
        <p className="text-xs text-gray-500 mb-3">
          Add both your ID number and photo to apply for verification.
        </p>

        <label className="block text-sm font-medium mb-1 text-gray-700">Description</label>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={3}
          className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-3 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
        />

        <label className="block text-sm font-medium mb-1 text-gray-700">Tax Bracket Tier</label>
        <input
          type="text"
          value={taxBracket}
          onChange={(e) => setTaxBracket(e.target.value)}
          className="w-full border border-gray-200 rounded-lg px-4 py-3 mb-4 focus:outline-none focus:ring-2 focus:ring-emerald-400 transition"
        />

        <button
          onClick={handleSave}
          disabled={loading}
          className="w-full bg-emerald-700 text-white py-3 rounded-lg font-medium hover:bg-emerald-800 transition shadow-md shadow-emerald-900/20 disabled:opacity-60"
        >
          {loading ? "Saving..." : "Save Profile"}
        </button>

        {error && <p className="text-red-600 text-sm mt-3 break-words">{error}</p>}
        {saved && (
          <div className="mt-5 flex items-center gap-2 bg-green-50 text-green-700 px-4 py-3 rounded-lg">
            <CheckCircle2 size={20} />
            <span className="font-medium">
              {submittedForReview
                ? "Profile saved and sent for verification."
                : "Profile saved!"}
            </span>
          </div>
        )}
      </div>
    </div>
  );
}

export default SellerProfile;
