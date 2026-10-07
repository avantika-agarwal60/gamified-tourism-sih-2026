import { PrismaClient } from '@prisma/client';
import crypto from "crypto";
import { awardXp } from "../../xp/xp.service.js";

const prisma = new PrismaClient();

const QUIZ_TIME_LIMIT_SECONDS = 120;
const MAX_QUIZ_ATTEMPTS = 3;
const MAX_LIVES = 4;
const COINS_PER_CORRECT_ANSWER = 2;

export async function startQuiz(req, res)
{
    const userId = req.user.id;
    const questId = req.params.questId;
    if (!userId || !questId) {
        return res.status(400).json({ message: "missing required fields" });
    }

    const progress = await prisma.quest_progress.findUnique({
        where: { user_id_quest_id: { user_id: userId, quest_id: questId } },
    });
    if (!progress || progress.status !== "started") {
        return res.status(400).json({ message: "quest not verified yet, cannot start quiz" });
    }

    const quest = await prisma.quests.findUnique({
        where: {
            id: questId,
        },
    });
    if (!quest) {
        return res.status(404).json({ message: "quest not found" });
    }
    const existingAttempts = await prisma.quiz_attempts.findMany({
        where: {
            user_id: userId,
            quest_id: questId,
        },
        orderBy: {
            attempt_number: 'desc',
        },
    });
    const lastAttempt = existingAttempts[0];
    if (lastAttempt && lastAttempt.status === 'in_progress') {
        const elapsedTime = (Date.now() - lastAttempt.started_at.getTime()) / 1000;
        if (elapsedTime > QUIZ_TIME_LIMIT_SECONDS) {
            await prisma.quiz_attempts.update({
                where: { id: lastAttempt.id },
                data: { status: 'expired', completed_at: new Date() },
            });

        } else
            {
            return res.status(409).json({ message: "quiz already in progress", attemptId: lastAttempt.id });
        }
    }
    const completedOrFailedAttemptsCount = existingAttempts.filter(attempt => attempt.status !="in_progress").length;
    if (completedOrFailedAttemptsCount >= MAX_QUIZ_ATTEMPTS) {
        return res.status(403).json({ message: "maximum quiz attempts reached" });
    }
    const questions = await prisma.quiz_questions.findMany({
        where: {
            quest_id: questId},
            select: {
                id: true,
                question: true,
                options: true},
});
if (questions.length === 0) {
    return res.status(404).json({ message: "no quiz questions found for this quest" });
}
try {
    const newAttempt = await prisma.quiz_attempts.create({
        data: {
            user_id: userId,
            quest_id: questId,
            id: crypto.randomUUID(),
            attempt_number: completedOrFailedAttemptsCount + 1,
            lives_left: MAX_LIVES,
        },
    });
    return res.status(200).json({ message: "quiz started", attemptId: newAttempt.id, questions: questions, timeLimit: QUIZ_TIME_LIMIT_SECONDS, lives: MAX_LIVES, attempts_remaining: MAX_QUIZ_ATTEMPTS - newAttempt.attempt_number });
}
catch (error) {
    console.error("Error starting quiz:", error);
    return res.status(500).json({ message: "internal server error" });
}
};

export async function submitAnswer(req,res)
{
    const {attemptId, questionId, selectedOption}=req.body;
    const userId= req.user.id;
    if (!attemptId|| !selectedOption || !questionId)
        return res.status(400).json({message: "missing required fields"});
    const attempt= await prisma.quiz_attempts.findUnique({
        where: {
            id: attemptId}
        });
        if (!attempt || attempt.user_id !== userId)
            return res.status(404).json({message: "quiz attempt not found"});
        if (attempt.status !== 'in_progress')
            return res.status(400).json({message: `quiz has already ${attempt.status}`});
        const elapsedTime = (Date.now() - attempt.started_at.getTime()) / 1000;
        if (elapsedTime > QUIZ_TIME_LIMIT_SECONDS) {
            await prisma.quiz_attempts.update({
                where: { id: attemptId },
                data: { status: 'expired', completed_at: new Date() },
            });
            return res.status(400).json({ message: "quiz time limit exceeded" });
        }
        const question= await prisma.quiz_questions.findUnique({
            where: {
                id: questionId,
            },
        });
        if(!question)
        {
            return res.status(404).json({message: "question not found"});
        }
        const alreadyAnswered = await prisma.quiz_answers.findFirst({
            where: {
                attempt_id: attemptId,
                question_id: questionId,
            },
        });
        if(alreadyAnswered)
        {
            return res.status(409).json({message: "question already answered"});
        }
        const isCorrect = selectedOption === question.correct_option;
        try
        {
            await prisma.quiz_answers.create({
                data: {
                    id: crypto.randomUUID(),
                    attempt_id: attemptId,
                    question_id: questionId,
                    selected_option: selectedOption,
                    is_correct: isCorrect,
                },

            });
            if (!isCorrect) {
                const updatedAttempt = await prisma.quiz_attempts.update({
                    where: { id: attemptId },
                    data: { lives_left: attempt.lives_left - 1 },
                });
                if (updatedAttempt.lives_left <= 0) {
                    await prisma.quiz_attempts.update({
                        where: { id: attemptId },
                        data: { status: 'failed', completed_at: new Date() },
                    });
                    return res.status(200).json({ message: "no lives left, quiz failed" });
                }
                return res.status(200).json({ message: "incorrect answer", lives_left: updatedAttempt.lives_left });
            } else {
                return res.status(200).json({ message: "correct answer" });
            }
        }
        catch (error) {
            console.error("Error submitting answer:", error);
            return res.status(500).json({ message: "internal server error" });
        }
}

export async function finishQuiz(req,res)
{
    const attemptId= req.params.attemptId;
    const userId=req.user.id;
    if (!attemptId)
        return res.status(400).json({message: "missing required fields"});


    const attempt = await prisma.quiz_attempts.findUnique({ where: { id: attemptId } });
    if (!attempt || attempt.user_id !== userId)
        return res.status(404).json({ message: "attempt not found" });

    if (attempt.status === "completed")
        return res.status(400).json({ message: "attempt already finished" });

     if (attempt.status === "failed" || attempt.status === "expired")
        return res.status(200).json({ message: "quiz ended", status: attempt.status, score: 0, discountPercent: 0 });
     const allAnswers = await prisma.quiz_answers.findMany({ where: { attempt_id: attemptId } });
     const allQuestions = await prisma.quiz_questions.findMany({ where: { quest_id: attempt.quest_id } });
     const correctAnswersCount = allAnswers.filter(answer => answer.is_correct).length;
     const score = allQuestions.length > 0 ? Math.round((correctAnswersCount / allQuestions.length) * 100) : 0;
     const level = await prisma.user_city_progress.findFirst({
        where: {
            user_id: userId,},
        });
        const currentLevel = level ?.level ?? 0;
    const discountPercent = Math.floor(score / 10)+currentLevel;
    try {
         await prisma.quiz_attempts.update({
            where: { id: attemptId },
            data: {
                status: "completed",
                score,
                discount_percent: discountPercent,
                completed_at: new Date(),
            },
        });


        const priorCompleted = await prisma.quiz_attempts.findFirst({
            where: {
                user_id: userId,
                quest_id: attempt.quest_id,
                status: "completed",
                id: { not: attemptId },
            },
        });

        let xpResult = { success: true, cityProgress: null };
        let coinsAwarded = 0;

        if (!priorCompleted) {
            const quest = await prisma.quests.findUnique({ where: { id: attempt.quest_id } });
            const progress = await prisma.quest_progress.findUnique({
                where: { user_id_quest_id: { user_id: userId, quest_id: attempt.quest_id } },
            });

            xpResult = await awardXp(userId, quest.city_id, quest.xp);
            coinsAwarded = (quest.coins ?? 0) + (correctAnswersCount * COINS_PER_CORRECT_ANSWER);

            await prisma.$transaction([
                prisma.users.update({
                    where: { id: userId },
                    data: { coins: { increment: coinsAwarded } },
                }),
                prisma.completed_quests.create({
                    data: {
                        id: crypto.randomUUID(),
                        user_id: userId,
                        quest_id: attempt.quest_id,
                        photo_url: progress?.photo_url ?? null,
                    },
                }),
            ]);
        }
        return res.status(200).json({
            message: "quiz completed",
            score,
            discountPercent,
            xpAwarded: !priorCompleted,
            coinsAwarded,
            cityProgress: xpResult.cityProgress,
        });
    } catch (err) {
        console.error("finishQuiz failed:", err);
        return res.status(500).json({ message: "failed to finish quiz" });
    }
}