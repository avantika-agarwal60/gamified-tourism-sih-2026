//import cities from "../quests/routes/cities.json" with { type: "json" };
//import quests from "../quests/routes/quests.json" with { type: "json" };
import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
const correctAnsXp = 10;
const reductionFactor = 0.3;
export async function calculateThreshold(cityName)
{
    if (!cityName)
        return { success: false, message: "missing required fields" };
    const city= await prisma.cities.findUnique({
        where: {
            name: cityName,
        },
    });
    if (!city)
        return { success: false, message: "city not found" };
    const totalQuests= await prisma.quests.findMany({
        where: {
            city_id: city.id,
        },
    });
    const totalQuestXp= () => {
        let sum=0;
        for(let i=0; i<totalQuests.length; i++) 
            sum+= totalQuests[i].xp ; 
        return sum;
    } 
    const totalXp= totalQuestXp() + (correctAnsXp * totalQuests.length * 5);
    const division= totalXp * reductionFactor;
    const levelThresholds= [];
    for (let i=0; i<5; i++)
    {
        levelThresholds.push(Math.floor(division * i));
    }
    await prisma.cities.update({
        where: {
            name: cityName,
        },
        data: {
            level_thresholds: levelThresholds,
        },
    });
    console.log(`Level thresholds for city ${cityName} calculated successfully:`, levelThresholds);
    return { success: true, level_thresholds: levelThresholds, message: "level thresholds calculated successfully" };
}
