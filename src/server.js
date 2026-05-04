import { createApp } from "./app.js";
import "./config/env.js";

const app = createApp();
const port = process.env.PORT || 4000;

app.listen(port, () => {
  console.log(`AI wellness backend listening on port ${port}`);
});
