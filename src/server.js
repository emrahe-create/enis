import express from "express";
import cors from "cors";

const app = express();

// 🔥 CORS CONFIG
const corsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);

    if (
      origin.startsWith("http://localhost") ||
      origin.startsWith("http://127.0.0.1") ||
      origin.includes("enisapp.com")
    ) {
      return callback(null, true);
    }

    console.log("CORS BLOCKED:", origin);
    return callback(new Error("Not allowed by CORS"));
  },
  methods: ["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  credentials: true,
};

// 🔥 EN ÖNEMLİ KISIM
app.use(cors(corsOptions));
app.options("*", cors(corsOptions));

// 👇 BU DA ÖNEMLİ
app.use(express.json());
