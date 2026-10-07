import { PrismaClient } from '@prisma/client';
import crypto from "crypto";
const prisma = new PrismaClient();

const MAX_LEVEL = 5;

export async function awardXp(userId, cityId, xp) {
    if (!userId || !cityId || !xp)
        return { success: false, message: "missing required fields" };

    const city = await prisma.cities.findUnique({ where: { id: cityId } });
    if (!city)
        return { success: false, message: "city not found" };

    const existing = await prisma.user_city_progress.findUnique({
        where: {
            user_id_city_id: { user_id: userId, city_id: cityId },
        },
    });

    const newXp = (existing?.xp ?? 0) + xp;

    let newLevel = 1;
    for (let i = 0; i < city.level_thresholds.length; i++) {
        if (newXp >= city.level_thresholds[i]) newLevel = i + 1;
    }
    newLevel = Math.min(newLevel, MAX_LEVEL);

    try {
        const cityProgress = await prisma.user_city_progress.upsert({
            where: {
                user_id_city_id: { user_id: userId, city_id: cityId },
            },
            update: { xp: newXp, level: newLevel },
            create: { user_id: userId, city_id: cityId, xp: newXp, level: newLevel, id: crypto.randomUUID() },
        });
        return { success: true, cityProgress };
    } catch (err) {
        console.error("awardXp failed:", err);
        return { success: false, message: "database error" };
    }
}