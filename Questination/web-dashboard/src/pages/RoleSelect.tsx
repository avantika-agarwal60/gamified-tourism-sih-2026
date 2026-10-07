import { useNavigate } from "react-router-dom";
import { useRole } from "../context/RoleContext";
import { Store, ShieldCheck } from "lucide-react";
import PalaceSkyline from "../components/PalaceSkyline";

function RoleSelect() {
  const { setRole } = useRole();
  const navigate = useNavigate();

  function handleSelect(role: "seller" | "admin") {
    setRole(role);
    navigate("/");
  }

  return (
    <div className="min-h-screen relative bg-gradient-to-br from-emerald-50 via-teal-50 to-amber-50 flex items-center justify-center overflow-hidden">
      <PalaceSkyline />
      <div className="relative bg-white p-10 rounded-2xl shadow-lg shadow-emerald-900/10 border border-amber-100 w-[420px] text-center">
        <h1 className="text-3xl font-bold text-gray-900 mb-1">Questination</h1>
        <p className="text-lg font-medium text-gray-600 mb-2">Welcome</p>
        <p className="text-gray-500 mb-8">Continue as:</p>

        <div className="flex flex-col gap-3">
          <button
            onClick={() => handleSelect("seller")}
            className="flex items-center gap-3 justify-center bg-emerald-700 text-white py-3 rounded-lg hover:bg-emerald-800 transition shadow-md shadow-emerald-900/20"
          >
            <Store size={20} /> Seller
          </button>
          <button
            onClick={() => handleSelect("admin")}
            className="flex items-center gap-3 justify-center bg-gray-800 text-white py-3 rounded-lg hover:bg-gray-900 transition"
          >
            <ShieldCheck size={20} /> Admin
          </button>
        </div>
      </div>
    </div>
  );
}

export default RoleSelect;