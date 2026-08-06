const {execFileSync} = require("node:child_process");

const projectId = process.argv[2] || "carrygo-bf7cb";
const databaseId = "(default)";

function getAccessToken() {
  try {
    return execFileSync("gcloud", ["auth", "print-access-token"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
  } catch (_) {
    const firebaseConfigPath = `${process.env.HOME}/.config/configstore/firebase-tools.json`;
    const firebaseConfig = require(firebaseConfigPath);
    const expiresAt = Number(firebaseConfig.tokens?.expires_at || 0);
    if (!firebaseConfig.tokens?.access_token || expiresAt < Date.now()) {
      throw new Error("No valid gcloud or Firebase CLI access token is available.");
    }
    return firebaseConfig.tokens.access_token;
  }
}

const token = getAccessToken();

const collections = {
  ratings: {
    orderId: "string",
    customerId: "string",
    riderId: "string",
    rating: "number",
    review: "string",
    createdAt: "timestamp",
  },
  notifications: {
    userId: "string | null",
    role: "customer | rider | admin | all",
    title: "string",
    body: "string",
    type: "order_status | payment | complaint | admin_broadcast",
    orderId: "string | null",
    isRead: "boolean",
    createdAt: "timestamp",
  },
  complaints: {
    orderId: "string",
    paymentReference: "string",
    customerId: "string",
    riderId: "string | null",
    type: "refund | wrong_item | damaged_item | late_delivery | other",
    reason: "string",
    status: "open | under_review | resolved | rejected | refunded",
    amountKobo: "number",
    adminNote: "string",
    createdAt: "timestamp",
    resolvedAt: "timestamp | null",
  },
};

function fieldValue(value) {
  if (typeof value === "boolean") return {booleanValue: value};
  if (typeof value === "number") return {doubleValue: value};
  if (value === null) return {nullValue: null};
  if (Array.isArray(value)) {
    return {arrayValue: {values: value.map(fieldValue)}};
  }
  if (typeof value === "object") {
    return {
      mapValue: {
        fields: Object.fromEntries(
          Object.entries(value).map(([key, nested]) => [key, fieldValue(nested)]),
        ),
      },
    };
  }
  return {stringValue: String(value)};
}

async function writeSchemaDoc(collection, fields) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/${encodeURIComponent(databaseId)}` +
    `/documents/${collection}/_schema`;
  const response = await fetch(url, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      fields: {
        is_schema_placeholder: {booleanValue: true},
        phase: {stringValue: "phase_2_mvp"},
        collection: {stringValue: collection},
        fields: fieldValue(fields),
        updatedAt: {timestampValue: new Date().toISOString()},
      },
    }),
  });

  if (!response.ok) {
    throw new Error(`${collection}: ${response.status} ${await response.text()}`);
  }
  return collection;
}

(async () => {
  const written = [];
  for (const [collection, fields] of Object.entries(collections)) {
    written.push(await writeSchemaDoc(collection, fields));
  }
  console.log(`Initialized Phase 2 collections in ${projectId}: ${written.join(", ")}`);
})().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
