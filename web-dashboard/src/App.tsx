import { BrowserRouter, Routes, Route } from "react-router-dom";
import { RoleProvider } from "./context/RoleContext";
import RequireRole from "./components/RequireRole";
import Layout from "./components/Layout";

import Login from "./pages/Login";
import Register from "./pages/Register";
import SellerProfile from "./pages/SellerProfile";
import MonumentSeeder from "./pages/MonumentSeeder";
import PromoteUser from "./pages/PromoteUser";
import VerifySeller from "./pages/VerifySeller";

function App() {
  return (
    <RoleProvider>
      <BrowserRouter>
        <Routes>

          {/* PUBLIC HOME / LOGIN — NO SIDEBAR */}
          <Route path="/" element={<Login />} />
          <Route path="/login" element={<Login />} />
          <Route path="/register" element={<Register />} />

          {/* PROTECTED DASHBOARD — SIDEBAR STARTS HERE */}
          <Route element={<RequireRole />}>
            <Route element={<Layout />}>

              {/* ADMIN */}
              <Route element={<RequireRole allowedRoles={["admin"]} />}>
                <Route path="/admin" element={<VerifySeller />} />
                <Route path="/monuments" element={<MonumentSeeder />} />
                <Route path="/promote" element={<PromoteUser />} />
              </Route>

              {/* SELLER */}
              <Route element={<RequireRole allowedRoles={["seller"]} />}>
                <Route path="/profile" element={<SellerProfile />} />
              </Route>

            </Route>
          </Route>

        </Routes>
      </BrowserRouter>
    </RoleProvider>
  );
}

export default App;