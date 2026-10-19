# Example: calton !3173, Support Microsoft MFA in the SSO E2E login (PAC-1523)

The change added TOTP-based MFA handling to a Cypress SSO login across nine
files, including a new helper module, a Cypress task, a page object rewrite and
a dependency swap. None of that appears below. The description names what a
reviewer can observe: what failed, what now happens, what was proven, what is
still missing.

```markdown
**Why:**

- Microsoft now enforces MFA on the SSO test accounts, so the scheduled SSO login fails for `ww` and `turo` at the verification step.
- The `ww` test account password had also been rotated, failing blue at the password step.

**What:**

- The SSO secret declares each account's MFA state: a `totpSecret` key means MFA is on, no key means it is off. A mismatch fails the SSO spec immediately with a message naming the account.
- With MFA on, the login answers Microsoft's verification code challenge with a code generated from the seed in Node. The seed never reaches the browser.
- A code with under eight seconds left is regenerated in the next window, and a rejected code is retried with the next window's code, up to three attempts.
- A rejected password and Microsoft's "Let's keep your account secure" registration page each fail fast with a specific message instead of a timeout.

**Demo:**

SSO spec passing with MFA against `turo` green and `ww` blue on 2026-10-09, with the task log showing the code generated and accepted.

**Testing:**

- Unit: RFC 6238 reference vectors, Microsoft's 10-byte seeds, spaced lowercase and padded seeds, and both timing behaviours.
- Local SSO spec runs against `turo` green and `ww` blue: passing.
- No exploratory testing from QE; this changes the test harness only.

**Missing:**

- The `ww` production SSO secret has neither the rotated password nor a `totpSecret`. After merge, the scheduled red job will fail with the message naming `test.user@wealthwizards.com`, which is the trigger to rotate it with the same seed as staging.

/assign me
/assign_reviewer @wealthwizards/planning-coaching

Closes %{source_branch}
```

What makes it work:

- **Why** states two failures a reviewer could reproduce. It does not mention TOTP.
- **What** has four behaviours. The one library-adjacent fact, "generated in Node", is there because it is a security property the reviewer must check, not because of the package chosen.
- **Demo** is dated evidence, not a promise.
- **Missing** names the follow-up and the exact signal that triggers it, so nobody has to remember.
