import { createContext, useContext, useState, type ReactNode } from "react";
import { decodeToken, getToken } from "../api/auth";

type Role = "seller" | "admin" | null;

interface RoleContextType {
  role: Role;
  setRole: (role: Role) => void;
}

const RoleContext = createContext<RoleContextType | undefined>(undefined);

function getInitialRole(): Role {
  const token = getToken();
  if (!token) return null;

  const decoded = decodeToken(token);
  return decoded?.role === "seller" || decoded?.role === "admin"
    ? decoded.role
    : null;
}

export function RoleProvider({ children }: { children: ReactNode }) {
  const [role, setRole] = useState<Role>(getInitialRole);

  return (
    <RoleContext.Provider value={{ role, setRole }}>
      {children}
    </RoleContext.Provider>
  );
}

export function useRole() {
  const context = useContext(RoleContext);
  if (!context) throw new Error("useRole must be used within RoleProvider");
  return context;
}
