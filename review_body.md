### PR Review: fix: add missing type field to OTel LLM panels (#252)

The changes in this PR look correct, complete, and address the rendering issues with the OTel Real-Time LLM Metric panels.

#### Summary of Observations
1. **Target Schema Fixes:** The 8 panels have been updated to include the missing target fields required by the InfluxDB SQL plugin (Flight SQL mode):
   - `"dataset": "iox"`
   - `"editorMode": "code"`
   - `"rawSql"` (correctly mirroring the query text)
   - `"sql"` metadata object with column function parameters.
2. **Panel Types:** The `type` field is correctly set to `"stat"`, `"timeseries"`, or `"table"` for all relevant panels.
3. **Stat Panels time column:** Added `MAX(time) AS time` to the queries for the stat panels (Input Tokens, Output Tokens, Total Cost, Avg Response Time) and set `resultFormat: "table"`. This is required to prevent the "no time column found" Grafana error.
4. **Documentation:** The updates to `.opencode/skills/grafana-dashboard-engineering/SKILL.md` are excellent and accurately document these target structure requirements, macros, stat panel limitations, and the Grafana API round-trip behavior.
