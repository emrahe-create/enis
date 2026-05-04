import cors from "cors";
import { createApp, corsOptions } from "./app.js";
import "./config/env.js";

const app = createApp({
  configureBeforeRoutes(app) {
    app.use(cors(corsOptions));
    app.options("*", cors(corsOptions));
  }
});
const port = process.env.PORT || 4000;

app.listen(port, () => {
  console.log(`AI wellness backend listening on port ${port}`);
});
