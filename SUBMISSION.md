# Submission

Fork URL: <!-- paste the URL of your fork here -->

## Files to commit

- [ ] `notes.md` with your policies and the commands you used (optional)

## Questions

Answer in your own words. Where a question asks for output, paste it in a code block.

### Q1. Paste your role's trust policy and its permission policy. Who may assume the role and what may they do? Why is `"Principal": "*"` in a trust policy dangerous?

**Your answer:**

<!-- replace this line with your answer -->

### Q2. Paste the output of `aws sts assume-role` with the secret values replaced by `...`. What are the three parts of temporary credentials and when do they stop working?

**Your answer:**

<!-- replace this line with your answer -->

### Q3. Show the commands that prove the role can write under `exports/` and cannot delete, cannot write outside the prefix and cannot list the other bucket. Paste the error messages. How do you read `AccessDenied` for an explicit versus an implicit deny?

**Your answer:**

<!-- replace this line with your answer -->

### Q4. The old access key was committed to git. List, in order, what you do in the first ten minutes (the key, the repository history, the audit). Why is deleting the file in a new commit not enough?

**Your answer:**

<!-- replace this line with your answer -->

### Q5. When would you use a role with an external id or MFA condition instead of a plain trust policy? Give one real example.

**Your answer:**

<!-- replace this line with your answer -->

### Q6. Paste the output of `./verify.sh`. It must end with **ALL CHECKS PASSED**.

**Your answer:**

<!-- replace this line with your answer -->

### Q7. **Tear down.** Paste the output of `./verify-teardown.sh`. It must end with **TEARDOWN VERIFIED**.

**Your answer:**

<!-- replace this line with your answer -->
