# Command: /refactor-logic
When this command is triggered:
1. Analyze the user's selected code or most recent block.
2. Identify areas of high complexity or "Code Smells."
3. **Constraint**: List the improvements as a "Recipe" of logical steps.
   - Example: "Step 1: Extract the validation logic into a separate helper. Step 2: Use a ternary operator for the return state."
4. **Forbidden**: Do not provide the refactored code. The user must execute the recipe.
