import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useRole } from "../context/RoleContext";
import { saveToken, saveRefreshToken, saveUserId, decodeToken } from "../api/auth";
import { LogIn, Store, ShieldCheck } from "lucide-react";
import AuthBackground from "../components/AuthBackground";

const API_BASE = "https://questination-production-08b6.up.railway.app";

function Login() {
  const [loginAs, setLoginAs] = useState<"seller" | "admin">("seller");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [notForDashboard, setNotForDashboard] = useState(false);
  const { setRole } = useRole();
  const navigate = useNavigate();

  async function handleLogin() {
    setLoading(true);
    setError("");
    setNotForDashboard(false);
    try {
      const response = await fetch(`${API_BASE}/auth/log-in`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      });

      const rawText = await response.text();
      let data: any = null;
      try {
        data = JSON.parse(rawText);
      } catch {
        setError(`Status ${response.status}. Raw response: ${rawText.slice(0, 200)}`);
        setLoading(false);
        return;
      }

      if (response.ok && data?.token) {
        saveToken(data.token);
        if (data.refreshtoken) saveRefreshToken(data.refreshtoken);

        const decoded = decodeToken(data.token);
        if (decoded) {
          saveUserId(decoded.id);
          if (decoded.role === "seller" || decoded.role === "admin") {
            // The API decides the real role. The toggle only indicates which
            // account type the user intended to use. Do not let an admin land
            // on the seller profile route.
            if (decoded.role !== loginAs) {
              setError(`These credentials belong to a ${decoded.role} account. Select ${decoded.role} and log in again.`);
              return;
            }

            setRole(decoded.role as "seller" | "admin");
            navigate(decoded.role === "admin" ? "/admin" : "/profile");
          } else {
            setNotForDashboard(true);
          }
        } else {
          setError("Login succeeded but token could not be decoded.");
        }
      } else {
        setError(`Status ${response.status}: ${data?.message || JSON.stringify(data)}`);
      }
    } catch (err: any) {
      setError(`Network error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }

  return (
    <AuthBackground>
      <div className="w-full max-w-[430px] rounded-xl border border-emerald-50 bg-white p-8 shadow-xl shadow-emerald-900/10">
        <h1 className="mb-1 text-3xl font-bold text-emerald-950">Login</h1>
        <p className="mb-6 text-sm text-gray-700">
          Welcome back! Please login to continue.
        </p>

        <div className="mb-5 flex gap-3">
          <button
            type="button"
            onClick={() => setLoginAs("seller")}
            className={`flex flex-1 items-center justify-center gap-2 rounded-lg py-2.5 text-sm font-medium transition ${
              loginAs === "seller" ? "bg-emerald-700 text-white" : "bg-gray-100 text-gray-600"
            }`}
          >
            <Store size={16} /> Seller
          </button>
          <button
            type="button"
            onClick={() => setLoginAs("admin")}
            className={`flex flex-1 items-center justify-center gap-2 rounded-lg py-2.5 text-sm font-medium transition ${
              loginAs === "admin" ? "bg-gray-800 text-white" : "bg-gray-100 text-gray-600"
            }`}
          >
            <ShieldCheck size={16} /> Admin
          </button>
        </div>

        <label className="mb-1 block text-sm font-medium text-gray-700">Email</label>
        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mb-3 w-full rounded-lg border border-gray-200 px-4 py-3 transition focus:outline-none focus:ring-2 focus:ring-emerald-400"
        />

        <label className="mb-1 block text-sm font-medium text-gray-700">Password</label>
        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-5 w-full rounded-lg border border-gray-200 px-4 py-3 transition focus:outline-none focus:ring-2 focus:ring-emerald-400"
        />

        <button
          onClick={handleLogin}
          disabled={loading}
          className="flex w-full items-center justify-center gap-2 rounded-lg bg-emerald-700 py-3 font-medium text-white transition hover:bg-emerald-800 disabled:opacity-60"
        >
          <LogIn size={18} /> {loading ? "Logging in..." : "Log In"}
        </button>

        {error && <p className="mt-3 break-words text-sm text-red-600">{error}</p>}
        {notForDashboard && (
          <p className="mt-3 text-sm text-amber-700">
            This dashboard is for sellers and admins only. Your account role doesn't have access here.
          </p>
        )}

        {loginAs === "seller" && (
          <p className="mt-5 text-center text-sm text-gray-700">
            Don't have an account?{" "}
            <Link to="/register" className="font-bold text-emerald-700 hover:text-emerald-800">
              Sign up
            </Link>
          </p>
        )}
        {loginAs === "admin" && (
          <p className="mt-5 text-center text-sm text-gray-500">
            Admin accounts are created by an existing admin, not through sign-up.
          </p>
        )}
      </div>
    </AuthBackground>
  );
}

export default Login;
