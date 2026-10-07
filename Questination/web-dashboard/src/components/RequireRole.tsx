import { Navigate, Outlet } from "react-router-dom";
import { useRole } from "../context/RoleContext";

type Role = "seller" | "admin";

function RequireRole({ allowedRoles }: { allowedRoles?: Role[] }) {
  const { role } = useRole();

  if (!role) {
    return <Navigate to="/login" replace />;
  }

  if (allowedRoles && !allowedRoles.includes(role)) {
    return <Navigate to={role === "admin" ? "/admin" : "/profile"} replace />;
  }

  return <Outlet />;
}

export default RequireRole;
