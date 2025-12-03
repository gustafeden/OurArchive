const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();

/**
 * Aggregates OurArchive stats and writes to public_stats collection
 * This data is publicly readable for the portfolio website
 */
async function aggregateStats() {
  console.log("Starting stats aggregation...");

  try {
    // Count users
    const usersSnap = await db.collection("users").count().get();
    const userCount = usersSnap.data().count;
    console.log(`Users: ${userCount}`);

    // Count households
    const householdsSnap = await db.collection("households").get();
    const householdCount = householdsSnap.size;
    console.log(`Households: ${householdCount}`);

    // Count all items across all households
    let itemCount = 0;
    for (const household of householdsSnap.docs) {
      const itemsSnap = await db
        .collection("households")
        .doc(household.id)
        .collection("items")
        .count()
        .get();
      itemCount += itemsSnap.data().count;
    }
    console.log(`Items: ${itemCount}`);

    // Count containers
    const containersSnap = await db.collection("containers").count().get();
    const containerCount = containersSnap.data().count;
    console.log(`Containers: ${containerCount}`);

    // Get item type breakdown (aggregate across households)
    const itemTypes = {};
    for (const household of householdsSnap.docs) {
      const itemsSnap = await db
        .collection("households")
        .doc(household.id)
        .collection("items")
        .get();

      for (const item of itemsSnap.docs) {
        const type = item.data().type || "unknown";
        itemTypes[type] = (itemTypes[type] || 0) + 1;
      }
    }
    console.log(`Item types:`, itemTypes);

    // Write to public stats document
    const now = new Date();
    const stats = {
      userCount,
      householdCount,
      itemCount,
      containerCount,
      itemTypes,
      lastUpdated: now,
    };

    await db.collection("public_stats").doc("ourarchive").set(stats);
    console.log("Stats written successfully:", stats);

    // Write to history subcollection (one doc per day)
    const dateStr = now.toISOString().split("T")[0]; // "2025-12-03"
    const historyDoc = {
      userCount,
      householdCount,
      itemCount,
      containerCount,
      itemTypes,
      date: now,
    };

    await db
      .collection("public_stats")
      .doc("ourarchive")
      .collection("history")
      .doc(dateStr)
      .set(historyDoc);
    console.log(`History written for ${dateStr}`);

    return stats;
  } catch (error) {
    console.error("Error aggregating stats:", error);
    throw error;
  }
}

// Scheduled function - runs daily at midnight UTC
exports.aggregateStatsScheduled = onSchedule(
  {
    schedule: "0 0 * * *", // Every day at midnight
    timeZone: "UTC",
    region: "europe-west1",
  },
  async (event) => {
    await aggregateStats();
  }
);

// HTTP trigger for manual updates (useful for testing)
exports.aggregateStatsHttp = onRequest(
  {
    region: "europe-west1",
    cors: true,
  },
  async (req, res) => {
    try {
      const stats = await aggregateStats();
      res.json({ success: true, stats });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  }
);
