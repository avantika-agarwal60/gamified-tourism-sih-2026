import { Navigate } from "react-router-dom";
import { useRole } from "../context/RoleContext";

export default function RoleHome() {
  const { role } = useRole();

  if (role === "admin") {
    return <Navigate to="/admin" replace />;
  }

  if (role === "seller") {
    return <Navigate to="/profile" replace />;
  }

  return <Navigate to="/login" replace />;
}