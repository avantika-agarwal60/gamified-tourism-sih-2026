//import users from "../routes/users.json" with {"type": "json"};
import bcrypt from "bcrypt";
import crypto from "crypto";
import jwt from "jsonwebtoken";
import dotenv from "dotenv";
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
dotenv.config({ path: new URL("../.env", import.meta.url) });
export async function register (req, res) {
    const { username, email, password, role, phone}=req.body;
    if (!username || !email || !password || !phone || !role) {
    return res.status(400).json({ message: "missing required fields" })
};
    const allowedRoles=["tourist", "seller"];
    if(!allowedRoles.includes(role))
        return res.status(400).json({message: "invalid role"});
    const isActive= true;
    let verificationStatus= 'not applicable';
    if (role=='seller')
        verificationStatus= 'PENDING';
    const isAlreadyRegistered= await prisma.users.findUnique({
        where: {
            email: email,
        },
    });
    if(isAlreadyRegistered)
    {
        return res.status(409).json({
            "message": "this account exists"
        });
    }
    const hashedPassword= await bcrypt.hash(password,10);
    const newUser= { username, email, hashedPassword, role, isActive, "id":crypto.randomUUID(), verificationStatus, phone};
    await prisma.users.create({ data: newUser});
    res.status(201).json({
        "message": "new user added"
    });
}
function GenerateToken (user)
{
    const token= jwt.sign(user, process.env.ACCESS_TOKEN_SECRET, {expiresIn: '15m'});
    return token;
}
export async function login (req,res)
{
    const {email, password}=req.body;
    if ( !email || !password) {
    return res.status(400).json({ message: "missing required fields" });
}
    const foundUser=await prisma.users.findUnique({
        where: {
            email: email,
        },
    });
    if (!foundUser || !foundUser.isActive)
        return res.status(401).json({message:"invalid credentials"});
    if (foundUser && await bcrypt.compare(password, foundUser.hashedPassword))
    {
        const user= { username: foundUser.username, id: foundUser.id, role: foundUser.role, isActive: foundUser.isActive};
        const token= GenerateToken(user);
        const refreshtoken= jwt.sign(user, process.env.REFRESH_TOKEN_SECRET, {expiresIn: '15d'});
try {
    await prisma.users.update({
        where: { id: foundUser.id },
        data: {
            Refresh_token: refreshtoken,
            refresh_expiry: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000),
        },
    });
} catch (err) {
    console.error("failed to persist refresh token:", err);
    return res.status(500).json({ message: "login failed" });
}
return res.json({token: token, Refresh_token: refreshtoken});
    }

    return res.status(401).json({
        "message": "invalid credentials"
    });
}
export async function refresh (req,res)
{
    let refreshtoken= req.body.refreshtoken;
    if (refreshtoken==null) return res.status(401).json({message: "refresh token not found"});
    const foundUser= await prisma.users.findFirst({
        where: {
            Refresh_token: refreshtoken,
        },
    });
    if (!foundUser)
        return res.status(401).json({
        "message": "invalid credentials"
    });
    if (!foundUser || !foundUser.isActive)
        return res.status(401).json({message:"access has been revoked"});
    jwt.verify(refreshtoken, process.env.REFRESH_TOKEN_SECRET, async (err,user)=>{ 
    if (err) return res.status(401).json({"message": "verification error"}); 
    user= {username: foundUser.username, id: foundUser.id, role: foundUser.role, isActive: foundUser.isActive};
    const newRefreshToken = jwt.sign(user, process.env.REFRESH_TOKEN_SECRET, {expiresIn: '15d'});
    try {
        await prisma.users.update({
            where: { id: foundUser.id },
            data: {
                Refresh_token: newRefreshToken,
                refresh_expiry: new Date(Date.now() + 15 * 24 * 60 * 60 * 1000),
            },
        });
    } catch (updateErr) {
        console.error("failed to rotate refresh token:", updateErr);
        return res.status(500).json({ message: "refresh failed" });
    }
    return res.json ({token: GenerateToken(user), Refresh_token: newRefreshToken})});
    
}
export async function authenticateToken (req,res,next)
{
    const authHeader=req.headers['authorization'];
    const token=  authHeader && req.headers['authorization'].split(" ")[1];
    if (token==null) return res.status(401).json({"message": "token not found"});
    jwt.verify(token, process.env.ACCESS_TOKEN_SECRET, async (err,user)=>{ 
    if (err) return res.status(401).json({message: "invalid token"});req.user=user;
    const foundUser= await prisma.users.findUnique({
        where: {
            id: user.id,
        },
    });
    if (!foundUser || !foundUser.isActive)
        return res.status(401).json({message:"access has been revoked"});
    if (foundUser.refresh_expiry && foundUser.refresh_expiry < new Date())
    return res.status(401).json({message:"refresh token expired"});
    next();});
}
export async function revoke(req, res)
{
    if (req.user.role !== "admin")
        return res.status(403).json({message: "unauthorized access"});

    const targetId = (req.params.id);
    const targetUser = await prisma.users.findUnique({
        where: {
            id: targetId,
        }
    });
    if (!targetUser)
        return res.status(404).json({message: "user not found"});

    await prisma.users.update({
        where: {
            id: targetId,
        },
        data: {
            isActive: false,
        }
    });
    return res.status(200).json({message: `access revoked for user ${targetId}`});
}
 export async function promotion(req,res)
 {
    if (req.user.role !== "admin")
        return res.status(403).json({message: "unauthorized access"});

    const targetId = (req.params.id);
    const targetUser = await prisma.users.findUnique({
        where: {
            id: targetId,
        },
    });
    if (!targetUser)
        return res.status(404).json({message: "user not found"});

    await prisma.users.update({
        where: {
            id: targetId,
        },
        data: {
            role: "admin",
        }
    });
    return res.status(200).json({message: `user ${targetId} has been promoted to admin`});
 }
