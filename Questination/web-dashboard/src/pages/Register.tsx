import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { UserPlus } from "lucide-react";
import AuthBackground from "../components/AuthBackground";

const API_BASE =
  "https://questination-production-08b6.up.railway.app";

function Register() {
  const [username, setUsername] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");

  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const [loading, setLoading] = useState(false);

  const navigate = useNavigate();

  async function handleRegister() {
    if (
      !username.trim() ||
      !email.trim() ||
      !password.trim() ||
      !phone.trim()
    ) {
      setError("Please fill in all fields.");
      return;
    }

    setLoading(true);
    setError("");
    setSuccess(false);

    try {
      const response = await fetch(`${API_BASE}/auth/register`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          username,
          email,
          password,
          phone,
          role: "seller",
        }),
      });

      const data = await response.json().catch(() => null);

      if (response.ok) {
        setSuccess(true);

        setTimeout(() => {
          navigate("/login");
        }, 1500);
      } else {
        setError(
          data?.message ||
            `Registration failed (status ${response.status})`
        );
      }
    } catch (err: any) {
      setError(`Network error: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }

  const inputClass =
    "mb-4 h-[51px] w-full rounded-[8px] border border-[#dce5e2] bg-white px-4 text-[14px] text-gray-800 outline-none transition focus:border-[#07875f] focus:ring-2 focus:ring-[#07875f]/15";

  return (
    <AuthBackground>
      <div className="w-full max-w-[515px] rounded-[15px] border border-[#edf0ee] bg-white px-9 py-8 shadow-[0_14px_40px_rgba(24,69,53,0.12)] sm:px-11 sm:py-9">

        <h1 className="text-[30px] font-bold leading-tight tracking-[-0.6px] text-[#183b34]">
          Create Account
        </h1>

        <p className="mt-2 mb-6 text-[14px] font-medium text-[#40504c]">
          Seller Sign Up
        </p>

        {/* USERNAME */}

        <label className="mb-2 block text-[14px] font-semibold text-[#203c36]">
          Username
        </label>

        <input
          type="text"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          autoComplete="username"
          className={inputClass}
        />

        {/* EMAIL */}

        <label className="mb-2 block text-[14px] font-semibold text-[#203c36]">
          Email
        </label>

        <input
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          autoComplete="email"
          className={inputClass}
        />

        {/* PHONE */}

        <label className="mb-2 block text-[14px] font-semibold text-[#203c36]">
          Phone
        </label>

        <input
          type="tel"
          value={phone}
          onChange={(e) => setPhone(e.target.value)}
          autoComplete="tel"
          className={inputClass}
        />

        {/* PASSWORD */}

        <label className="mb-2 block text-[14px] font-semibold text-[#203c36]">
          Password
        </label>

        <input
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              handleRegister();
            }
          }}
          autoComplete="new-password"
          className="mb-5 h-[51px] w-full rounded-[8px] border border-[#dce5e2] bg-white px-4 text-[14px] text-gray-800 outline-none transition focus:border-[#07875f] focus:ring-2 focus:ring-[#07875f]/15"
        />

        {/* CREATE ACCOUNT */}

        <button
          type="button"
          onClick={handleRegister}
          disabled={loading}
          className="flex h-[51px] w-full items-center justify-center gap-2 rounded-[8px] bg-[#07875f] text-[15px] font-semibold text-white shadow-sm transition hover:bg-[#067650] disabled:cursor-not-allowed disabled:opacity-60"
        >
          <UserPlus size={18} />

          {loading ? "Creating..." : "Create Account"}
        </button>

        {/* ERROR */}

        {error && (
          <p className="mt-4 break-words rounded-[7px] bg-red-50 p-3 text-sm text-red-600">
            {error}
          </p>
        )}

        {/* SUCCESS */}

        {success && (
          <p className="mt-4 rounded-[7px] bg-green-50 p-3 text-sm text-green-700">
            Account created! Redirecting to login...
          </p>
        )}

        {/* LOGIN */}

        <p className="mt-6 text-center text-[14px] text-[#53615e]">
          Already have an account?{" "}
          <Link
            to="/login"
            className="font-bold text-[#07875f] hover:text-[#056a4b]"
          >
            Log in
          </Link>
        </p>

      </div>
    </AuthBackground>
  );
}

export default Register;