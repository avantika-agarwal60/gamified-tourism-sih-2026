import 'dotenv/config';
import { calculateThreshold } from "./threshold.service.js";
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function run() {
    console.log("starting threshold run...");
    try {
        const cities = await prisma.cities.findMany();
        console.log(`found ${cities.length} cities`);

        for (const city of cities) {
            console.log(`processing ${city.name}...`);
            await calculateThreshold(city.name);
        }

        console.log("Level thresholds calculated for all cities.");
    } catch (err) {
        console.error("run() failed:", err);
    } finally {
        await prisma.$disconnect();
    }
}

run();