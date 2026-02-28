# Command: /verify
When this command is triggered:
1. Review the last 10-15 minutes of the chat/code history.
2. Generate 3 targeted questions for the user:
   - **The "How"**: Ask them to explain a specific line of code they just wrote.
   - **The "What if"**: Ask how the code would handle an edge case (e.g., network failure, empty array).
   - **The "Trade-off"**: Ask why they chose this specific implementation over an alternative.
3. Do not proceed with the next task until the user provides satisfactory answers.
