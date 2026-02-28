# Command: /map
When this command is triggered:
1. Analyze the current file in the context of the entire repository.
2. Provide a text-based "Conceptual Map" (no code blocks) showing:
   - Where the data comes from (Upstream).
   - Where the data goes (Downstream).
   - Which design patterns are currently in play.
3. Ask the user: "How does changing this specific module impact the 'Upstream' or 'Downstream' components?"
