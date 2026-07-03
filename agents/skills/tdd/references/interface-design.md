# Interface Design for Testability

Good interfaces make testing natural:

1. **Accept dependencies, don't create them**

   ```typescript
   // Testable
   function calculateRetirementProjection(plan, taxClient) {}

   // Hard to test
   function calculateRetirementProjection(plan) {
     const taxClient = new IncomeTaxServiceClient();
   }
   ```

2. **Return results, don't produce side effects**

   ```typescript
   // Testable
   function calculateAnnualIncome(pot, drawdownRate): IncomeProjection {}

   // Hard to test
   function applyDrawdown(user): void {
     user.pot -= annualDrawdown;
   }
   ```

3. **Small surface area**
   - Fewer methods = fewer tests needed
   - Fewer params = simpler test setup
