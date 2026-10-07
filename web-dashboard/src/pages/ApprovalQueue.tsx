import { useEffect, useState } from "react";
import { authFetch } from "../api/authFetch"; // adjust the path if this file lives in a subfolder

const API_BASE = "https://questination-production-08b6.up.railway.app";

// ---------- Types ----------
type PendingSeller = {
  id: string;
  shop_name: string;
  description: string | null;
  address: string | null;
  udyam_id: string | null;
  udyam_proof_url: string | null;
  city_id: string | null;
  craft_category_id: string | null;
  cities?: { id: string; name: string } | null;
  craft_categories?: { id: string; name: string } | null;
  users?: { username: string; email: string } | null;
};

type City = { id: string; name: string };
type CraftCategory = { id: string; name: string };

// ---------- API helper ----------
async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const res = await authFetch(`${API_BASE}/api/sellers${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...options.headers,
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error ?? "Request failed");
  return data as T;
}

export default function ApprovalQueue() {
  const [sellers, setSellers] = useState<PendingSeller[]>([]);
  const [cities, setCities] = useState<City[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");

  const [selected, setSelected] = useState<PendingSeller | null>(null);
  const [cityId, setCityId] = useState("");
  const [craftName, setCraftName] = useState("");
  const [categories, setCategories] = useState<CraftCategory[]>([]);

  const [saving, setSaving] = useState(false);
  const [modalError, setModalError] = useState("");
  const [message, setMessage] = useState("");

  // Load pending sellers + cities once
  useEffect(() => {
    (async () => {
      try {
        setSellers(await api<PendingSeller[]>("/pending"));
      } catch (err) {
        setLoadError(err instanceof Error ? err.message : "Failed to load applications");
      } finally {
        setLoading(false);
      }

      // Cities load separately so a missing /meta/cities route doesn't hide the queue
      try {
        setCities(await api<City[]>("/meta/cities"));
      } catch {
        setCities([]);
      }
    })();
  }, []);

  // Load existing craft categories whenever the selected city changes
  useEffect(() => {
    if (!cityId) {
      setCategories([]);
      return;
    }
    api<CraftCategory[]>(`/meta/craft-categories?city_id=${encodeURIComponent(cityId)}`)
      .then(setCategories)
      .catch(() => setCategories([]));
  }, [cityId]);

  const openReview = (seller: PendingSeller) => {
    setSelected(seller);
    setCityId(seller.city_id ?? "");
    setCraftName(seller.craft_categories?.name ?? "");
    setModalError("");
    setMessage("");
  };

  const closeReview = () => {
    if (saving) return;
    setSelected(null);
  };

  const removeFromQueue = (id: string) =>
    setSellers((prev) => prev.filter((s) => s.id !== id));

  const handleVerify = async () => {
    if (!selected) return;
    if (!cityId || !craftName.trim()) {
      setModalError("Choose a city and enter a craft category before verifying.");
      return;
    }

    setSaving(true);
    setModalError("");
    try {
      // 1. Save the (possibly edited) city + craft category
      await api(`/${selected.id}/verify-craft`, {
        method: "PUT",
        body: JSON.stringify({ craftName: craftName.trim(), city_id: cityId }),
      });
      // 2. Mark the seller's account as verified
      await api(`/${selected.id}/verification`, {
        method: "PUT",
        body: JSON.stringify({ status: "verified" }),
      });

      removeFromQueue(selected.id);
      setMessage(`${selected.shop_name} has been verified successfully.`);
      setSelected(null);
    } catch (err) {
      setModalError(err instanceof Error ? err.message : "Could not verify seller.");
    } finally {
      setSaving(false);
    }
  };

  const handleReject = async () => {
    if (!selected) return;

    setSaving(true);
    setModalError("");
    try {
      await api(`/${selected.id}/verification`, {
        method: "PUT",
        body: JSON.stringify({ status: "rejected" }),
      });

      removeFromQueue(selected.id);
      setMessage(`${selected.shop_name} has been rejected.`);
      setSelected(null);
    } catch (err) {
      setModalError(err instanceof Error ? err.message : "Could not reject seller.");
    } finally {
      setSaving(false);
    }
  };

  const handleViewProof = async () => {
    if (!selected) return;
    setModalError("");
    try {
      const { url } = await api<{ url: string }>(`/${selected.id}/udyam-proof-url`);
      window.open(url, "_blank", "noopener,noreferrer");
    } catch (err) {
      setModalError(err instanceof Error ? err.message : "Could not open proof document.");
    }
  };

  return (
    <div className="space-y-8">
      {/* HEADER */}
      <div>
        <h1 className="text-3xl font-bold text-[#064f42]">Verify Seller</h1>
        <p className="mt-2 text-gray-600">
          Review pending seller applications before approving them.
        </p>
      </div>

      {/* STATUS MESSAGE */}
      {message && (
        <div className="rounded-xl border border-[#b9e4d8] bg-[#f0faf7] px-5 py-4 text-sm font-semibold text-[#087f68]">
          {message}
        </div>
      )}

      {/* PENDING APPLICATIONS */}
      <div className="rounded-2xl bg-white p-6 shadow-sm">
        <div className="mb-6 flex items-center justify-between">
          <div>
            <h2 className="text-xl font-bold text-[#064f42]">
              Pending Seller Applications
            </h2>
            <p className="mt-1 text-sm text-gray-500">
              Select an application to review the submitted seller details.
            </p>
          </div>

          <span className="rounded-full bg-[#e8f7f2] px-4 py-2 text-sm font-semibold text-[#087f68]">
            {sellers.length} Pending
          </span>
        </div>

        {loading ? (
          <p className="py-12 text-center text-sm text-gray-500">Loading applications…</p>
        ) : loadError ? (
          <div className="rounded-xl border border-red-200 bg-red-50 px-6 py-8 text-center">
            <p className="font-semibold text-red-600">{loadError}</p>
            <button
              type="button"
              onClick={() => window.location.reload()}
              className="mt-3 text-sm font-semibold text-red-600 underline"
            >
              Reload
            </button>
          </div>
        ) : sellers.length === 0 ? (
          <div className="rounded-xl border border-dashed border-gray-200 px-6 py-12 text-center">
            <p className="font-semibold text-gray-600">No pending seller applications.</p>
            <p className="mt-1 text-sm text-gray-400">
              New seller applications will appear here.
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            {sellers.map((seller) => (
              <div
                key={seller.id}
                className="flex flex-col gap-5 rounded-xl border border-gray-100 p-5 transition hover:border-[#b9e4d8] hover:bg-[#fbfefd] md:flex-row md:items-center md:justify-between"
              >
                <div className="min-w-0">
                  <h3 className="text-lg font-bold text-gray-800">{seller.shop_name}</h3>

                  <div className="mt-2 flex flex-wrap gap-x-5 gap-y-1 text-sm text-gray-500">
                    <span>{seller.craft_categories?.name ?? "No craft set"}</span>
                    <span>{seller.cities?.name ?? "No city set"}</span>
                    {seller.address && <span>{seller.address}</span>}
                  </div>

                  <p className="mt-2 text-xs text-gray-400">Seller ID: {seller.id}</p>
                </div>

                <button
                  type="button"
                  onClick={() => openReview(seller)}
                  className="shrink-0 rounded-xl border border-[#087f68] px-5 py-2.5 font-semibold text-[#087f68] transition hover:bg-[#087f68] hover:text-white"
                >
                  Review
                </button>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* REVIEW MODAL */}
      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4">
          <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-2xl bg-white p-6 shadow-2xl">
            {/* HEADER */}
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-sm font-semibold text-[#087f68]">Seller Application</p>
                <h2 className="mt-1 text-2xl font-bold text-[#064f42]">
                  {selected.shop_name}
                </h2>
              </div>

              <button
                type="button"
                onClick={closeReview}
                className="text-2xl leading-none text-gray-400 hover:text-gray-700"
                aria-label="Close"
              >
                ×
              </button>
            </div>

            {/* SUBMITTED DETAILS (read-only) */}
            <div className="mt-6 overflow-hidden rounded-xl border border-gray-100">
              <div className="grid grid-cols-1 divide-y divide-gray-100 md:grid-cols-2 md:divide-x md:divide-y-0">
                <Field label="Seller/User ID" value={selected.id} />
                <Field label="Shop Name" value={selected.shop_name} />
              </div>

              <div className="border-t border-gray-100">
                <Field label="Address" value={selected.address ?? "—"} />
              </div>

              <div className="grid grid-cols-1 divide-y divide-gray-100 border-t border-gray-100 md:grid-cols-2 md:divide-x md:divide-y-0">
                <Field label="UDYAM / Document ID" value={selected.udyam_id ?? "—"} />
                <div className="p-4">
                  <p className="text-xs font-semibold uppercase tracking-wide text-gray-400">
                    Proof document
                  </p>
                  {selected.udyam_proof_url ? (
                    <button
                      type="button"
                      onClick={handleViewProof}
                      className="mt-1 font-medium text-[#087f68] underline hover:text-[#066a58]"
                    >
                      View proof
                    </button>
                  ) : (
                    <p className="mt-1 font-medium text-gray-800">Not uploaded</p>
                  )}
                </div>
              </div>
            </div>

            {/* EDITABLE: CITY + CRAFT CATEGORY */}
            <div className="mt-5 rounded-xl border border-[#b9e4d8] bg-[#f5faf8] p-4">
              <p className="text-sm font-semibold text-[#064f42]">
                City and craft category
              </p>
              <p className="mt-1 text-sm text-gray-600">
                Correct these if the seller picked the wrong ones. They are saved when you
                verify.
              </p>

              <div className="mt-4 grid grid-cols-1 gap-4 md:grid-cols-2">
                <label className="block">
                  <span className="text-xs font-semibold uppercase tracking-wide text-gray-500">
                    City
                  </span>
                  <select
                    value={cityId}
                    onChange={(e) => setCityId(e.target.value)}
                    disabled={saving}
                    className="mt-1 w-full rounded-lg border border-gray-200 bg-white px-3 py-2.5 text-gray-800 focus:border-[#087f68] focus:outline-none focus:ring-2 focus:ring-[#087f68]/20"
                  >
                    <option value="">Select a city</option>
                    {cities.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </label>

                <label className="block">
                  <span className="text-xs font-semibold uppercase tracking-wide text-gray-500">
                    Craft category
                  </span>
                  <input
                    type="text"
                    list="craft-category-options"
                    value={craftName}
                    onChange={(e) => setCraftName(e.target.value)}
                    disabled={saving || !cityId}
                    placeholder={cityId ? "e.g. Chikankari" : "Select a city first"}
                    className="mt-1 w-full rounded-lg border border-gray-200 bg-white px-3 py-2.5 text-gray-800 focus:border-[#087f68] focus:outline-none focus:ring-2 focus:ring-[#087f68]/20 disabled:bg-gray-50"
                  />
                  <datalist id="craft-category-options">
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.name} />
                    ))}
                  </datalist>
                </label>
              </div>

              <p className="mt-2 text-xs text-gray-500">
                Pick an existing category from the list, or type a new name to create it for
                this city.
              </p>
            </div>

            {/* ERROR */}
            {modalError && (
              <div className="mt-4 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-medium text-red-600">
                {modalError}
              </div>
            )}

            {/* ACTIONS */}
            <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
              <button
                type="button"
                onClick={handleReject}
                disabled={saving}
                className="rounded-xl border border-red-200 px-6 py-3 font-semibold text-red-600 transition hover:bg-red-50 disabled:opacity-50"
              >
                Reject
              </button>

              <button
                type="button"
                onClick={handleVerify}
                disabled={saving}
                className="rounded-xl bg-[#087f68] px-6 py-3 font-semibold text-white transition hover:bg-[#066a58] disabled:opacity-50"
              >
                {saving ? "Saving…" : "Verify Seller"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="p-4">
      <p className="text-xs font-semibold uppercase tracking-wide text-gray-400">{label}</p>
      <p className="mt-1 break-words font-medium text-gray-800">{value}</p>
    </div>
  );
}
