import { Outlet, Link, useLocation } from "react-router-dom";
import { Store, ShieldCheck, Landmark, UserCog } from "lucide-react";
import { useRole } from "../context/RoleContext";
import PalaceSkyline from "./PalaceSkyline";

const navItems = [
  { to: "/profile", label: "Seller Profile", icon: Store, roles: ["seller"] },
  { to: "/admin", label: "Verify Seller", icon: ShieldCheck, roles: ["admin"] },
  { to: "/monuments", label: "Add Monument", icon: Landmark, roles: ["admin"] },
  { to: "/promote", label: "Promote to Admin", icon: UserCog, roles: ["admin"] },
];

function Layout() {
  const location = useLocation();
  const { role } = useRole();

  const visibleItems = navItems.filter((item) => item.roles.includes(role || ""));

  return (
    <div className="flex min-h-screen">
      <aside className="w-64 bg-gradient-to-b from-[#3a6b5f] to-[#2a4d44] text-white flex flex-col">
        <div className="p-6 border-b border-white/10">
          <h1 className="text-xl font-bold text-amber-200">Questination</h1>
          <p className="text-xs text-emerald-100/70 mt-1">Partner Dashboard</p>
          <p className="text-xs text-emerald-100/70 mt-1 capitalize">Logged in as: {role}</p>
        </div>
        <nav className="flex-1 p-4 flex flex-col gap-1">
          {visibleItems.map(({ to, label, icon: Icon }) => {
            const active = location.pathname === to;
            return (
              <Link
                key={to}
                to={to}
                className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition ${
                  active
                    ? "bg-amber-400 text-emerald-900 shadow"
                    : "text-emerald-100/80 hover:bg-white/10"
                }`}
              >
                <Icon size={18} />
                {label}
              </Link>
            );
          })}
        </nav>
      </aside>

      <main className="flex-1 relative bg-gradient-to-br from-emerald-50 via-teal-50 to-amber-50 min-h-screen overflow-hidden">
        <PalaceSkyline />
        <div className="relative p-10 pb-24">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

export default Layout;