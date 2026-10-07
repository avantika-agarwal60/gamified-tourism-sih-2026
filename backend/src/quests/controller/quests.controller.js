import { getDistanceKm } from "../../common/utils/geodistance.js";
import { PrismaClient } from '@prisma/client';
import crypto from "crypto"
const prisma = new PrismaClient();

export async function getQuests(req,res)
{
    const {city_id}=req.query;
    if (!city_id)
        return res.status(200).json({quests: await prisma.quests.findMany()});  
    const quests= await prisma.quests.findMany({
        where: {
            city_id: city_id,
        },
    });
    if (quests.length===0)
        return res.status(404).json({message: "no quests found in the specified city"});
    return res.status(200).json({quests: quests});
}

export async function getCities(req,res)
{
    const cities= await prisma.cities.findMany({
        include: {
            quests: {
                select: {
                    lat: true,
                    lng: true,
                },
            },
        },
    });
    if (cities.length===0)
        return res.status(404).json({message: "no cities found"});
    return res.status(200).json({cities: cities});
}

export async function createQuestPhotoUploadUrl(req, res) {
    const {questId, fileName, contentType} = req.body;
    const supabaseUrl = process.env.SUPABASE_URL?.replace(/\/$/, "");
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    const bucket = process.env.SUPABASE_QUEST_PHOTO_BUCKET || "quest-evidence";
    const allowedTypes = new Set(["image/jpeg", "image/png", "image/webp"]);

    if (!questId || !fileName || !allowedTypes.has(contentType))
        return res.status(400).json({message: "questId, fileName, and supported image contentType are required"});
    if (!supabaseUrl || !serviceRoleKey)
        return res.status(500).json({message: "quest photo storage is not configured"});

    try {
        const quest = await prisma.quests.findUnique({
            where: {id: questId},
            select: {id: true},
        });
        if (!quest)
            return res.status(404).json({message: "quest not found"});

        const safeQuestId = questId.replace(/[^A-Za-z0-9_-]/g, "_");
        const safeFileName = fileName.replace(/[^A-Za-z0-9._-]/g, "_");
        const objectPath = `${safeQuestId}/${crypto.randomUUID()}-${safeFileName}`;
        const encodePath = value => value.split("/").map(encodeURIComponent).join("/");
        const encodedBucket = encodeURIComponent(bucket);
        const encodedPath = encodePath(objectPath);
        const signResponse = await fetch(
            `${supabaseUrl}/storage/v1/object/upload/sign/${encodedBucket}/${encodedPath}`,
            {
                method: "POST",
                headers: {
                    apikey: serviceRoleKey,
                    Authorization: `Bearer ${serviceRoleKey}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({upsert: false}),
            },
        );
        const signData = await signResponse.json();
        if (!signResponse.ok) {
            console.error("Supabase signed upload URL failed:", signData);
            return res.status(502).json({message: "could not prepare quest photo upload"});
        }

        const signedPath = signData.signedURL || signData.signedUrl || signData.url;
        let uploadUrl = null;
        if (typeof signedPath === "string") {
            uploadUrl = /^https?:\/\//i.test(signedPath)
                ? signedPath
                : signedPath.startsWith("/storage/v1/")
                    ? `${supabaseUrl}${signedPath}`
                    : `${supabaseUrl}/storage/v1/${signedPath.replace(/^\/+/, "")}`;
        } else if (signData.token) {
            uploadUrl = `${supabaseUrl}/storage/v1/object/upload/sign/${encodedBucket}/${encodedPath}?token=${encodeURIComponent(signData.token)}`;
        }
        if (!uploadUrl)
            return res.status(502).json({message: "Supabase did not return an upload token"});

        return res.status(200).json({
            uploadUrl,
            publicUrl: `${supabaseUrl}/storage/v1/object/public/${encodedBucket}/${encodedPath}`,
            path: objectPath,
        });
    } catch (error) {
        console.error("Creating quest photo upload URL failed:", error);
        return res.status(500).json({message: "could not prepare quest photo upload"});
    }
}

export async function questById(req,res)
{
    const {id}=req.params;
    if (!id)
        return res.status(400).json({message: "missing required fields"});
    const quest= await prisma.quests.findUnique({
        where: {
            id: id,
        },
    });
    if (!quest)
        return res.status(404).json({message: "quest not found"});  
    return res.status(200).json({quest: quest});
}

export async function questAccept(req, res) {
    const questId = req.params.id;
    const userId = req.user.id;
    if (!questId || !userId)
        return res.status(400).json({ message: "missing required fields" });

    const quest = await prisma.quests.findUnique({ where: { id: questId } });
    if (!quest)
        return res.status(404).json({ message: "quest not found" });

    const alreadyCompleted = await prisma.completed_quests.findFirst({
        where: { user_id: userId, quest_id: questId },
    });
    if (alreadyCompleted)
        return res.status(409).json({ message: "quest already completed" });

    try {
        const progress = await prisma.quest_progress.upsert({
            where: { user_id_quest_id: { user_id: userId, quest_id: questId } },
            update: {},
            create: {
                id: crypto.randomUUID(),
                user_id: userId,
                quest_id: questId,
                status: "accepted",
            },
        });
        return res.status(200).json({ message: "quest accepted", progress });
    } catch (error) {
        console.error("Error accepting quest:", error);
        return res.status(500).json({ message: "internal server error" });
    }
}
export async function getCompletedQuests(req, res) {
    const rows = await prisma.completed_quests.findMany({
        where: { user_id: req.user.id },
        include: { quests: true },
        orderBy: { completed_at: 'asc' },
    });
    return res.status(200).json({ completedQuests: rows });
}
export async function questCompletion(req,res)
{
    const questId=req.params.id;
    const {lat, lng, qr_code, photoUrl}= req.body;
    const userId=req.user.id;
    const supabaseUrl = process.env.SUPABASE_URL?.replace(/\/$/, "");
    const bucket = process.env.SUPABASE_QUEST_PHOTO_BUCKET || "quest-evidence";
    const expectedPhotoPrefix = supabaseUrl
        ? `${supabaseUrl}/storage/v1/object/public/${encodeURIComponent(bucket)}/`
        : null;
    if (!questId || !userId || lat == null || lng == null || !qr_code ||
        typeof photoUrl !== "string" || !expectedPhotoPrefix ||
        !photoUrl.startsWith(expectedPhotoPrefix) ||
        photoUrl.length > 2048)
        return res.status(400).json({message: "missing required fields, quest incomplete"});
    const user= await prisma.users.findUnique({
        where: {
            id: userId,
        },
    });
    if (!user)
        return res.status(404).json({message: "user not found"});
    const alreadyCompleted = await prisma.completed_quests.findFirst({
    where: {
        user_id: userId,
        quest_id: questId,
    },
});
if (alreadyCompleted) {
    return res.status(409).json({ message: "quest already completed" });
};
    const progress = await prisma.quest_progress.findUnique({
        where: { user_id_quest_id: { user_id: userId, quest_id: questId } },
    });
    if (!progress)
        return res.status(400).json({ message: "quest not accepted yet" });

    const quest=await prisma.quests.findUnique({
        where: {
            id: questId,
        },
    });
    if (!quest)
        return res.status(404).json({message: "quest not found"});
    const distance= getDistanceKm(lat, lng, quest.lat, quest.lng);
    
    if (distance>0.05)
        return res.status(400).json({message: "user is not at the quest location, quest incomplete"});
    if (qr_code!==quest.qr_code)
        return res.status(400).json({message: "invalid QR code, quest incomplete"});
    const city= await prisma.cities.findUnique({
        where: {
            id: quest.city_id,
        },
    });
    if (!city)
        return res.status(404).json({message: "city not found"});

    await prisma.quest_progress.update({
        where: { user_id_quest_id: { user_id: userId, quest_id: questId } },
        data: { status: "started", started_at: new Date(), photo_url: photoUrl },
    });

    return res.status(200).json({
        message: "checks passed, spawn guide",
        guide: {
            dialogue: quest.guide_dialogue,
        },
    });
}
