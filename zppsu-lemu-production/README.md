# ZPPSU LEMU — Final Prototype Handoff

Responsive Next.js + Supabase starter for the Zamboanga Peninsula Polytechnic State University Licensure Examination Management Unit.

## Institutional branding and supplied materials
- Official ZPPSU university seal in `public/logos/zppsu-university.png`.
- Supplied College of Engineering and Technology, College of Physical Education and Sports, and College of Teacher Education seals in `public/logos/`.
- Original LET compilation downloadable from the Reviewer page: `public/reviewers/LET_Previous_Actual_Test_PRC_Format.docx`.

## LET source compilation — handling notes
The supplied document identifies 10 exam sets × 150 items = 1,500 items, covering General Education and Professional Education for elementary and secondary levels (2015–2018). Its contents page flags 68 items as unclear or incomplete across the sets. The compiler's notes state that no highlighted answers or answer key were supplied; each set's answer-key page is blank. The portal therefore provides the original document as a downloadable source only. It does **not** claim the 1,500 questions have been imported, verified, keyed, or explained. An authorized LET subject reviewer must validate each item and key before it is published for scoring.

## Current prototype features
- Responsive maroon-and-gold institutional landing page with official seals.
- Supabase email/password registration and login; profile created from Auth signup metadata.
- BEED/BSED reviewer section and download of the original LET DOCX.
- Published-question display and administrator question-entry form.
- 30-minute mock exam UI for approved students.
- Server-side grading RPC (`submit_lemu_exam`); student-facing question query does not return correct answers or explanations.
- Student result history.
- Admin student approval/rejection and payment-record review screen.
- GCash collection deliberately disabled pending official ZPPSU account confirmation.

## Important scope boundaries
This is a working application starter/prototype, not a deployed or institutionally audited production service. No live database credentials, hosting account, official GCash details, fee schedule, privacy notice, or designated admin email were supplied. Accordingly, no public deployment or real payment collection has been activated. The question bank starts empty; the uploaded compilation is a downloadable source file, not a populated verified database.

The prototype currently supports score and attempt history, but a public leaderboard, comprehensive subject analytics, downloadable cheat-sheet library, receipt upload/storage, exam randomization, per-section exam configuration, and audit/export reports still require implementation and institutional decisions.

## Setup
1. Create a Supabase project.
2. Run `supabase/schema.sql` in the Supabase SQL Editor on a **new/empty** project.
3. Copy `.env.example` to `.env.local` and set the Supabase Project URL and anon/publishable key.
4. Install Node.js 20+ dependencies and start locally:

   ```bash
   npm install
   npm run dev
   ```

5. Open `http://localhost:3000`.

## Promote the designated administrator
Register the official administrator through the website, then run this in Supabase SQL Editor after verifying the exact institutional email address:

```sql
update public.profiles
set role = 'admin', approval_status = 'approved'
where email = 'AUTHORIZED-ADMIN@zppsu.edu.ph';
```

Do not promote an unverified account. Require MFA for administrator accounts where available.

## Security and operational notes
- Correct answers and explanations are stored separately in `question_answers`, protected by RLS, and are not selected by the student question-bank query.
- `submit_lemu_exam` grades on the database side and checks that the authenticated student is approved and taking their registered program.
- Never put a Supabase service-role key in browser code or any `NEXT_PUBLIC_*` variable.
- GCash is not configured. Do not accept transfers until ZPPSU formally secures the account, confirms the account name/number, approves the fee and instructions, and designates staff for reconciliation.
- Payment review controls are present for administrator use if payment records exist, but student payment submission and collection remain off in the UI until official payment configuration is completed.
- The original LET compilation's answer keys are blank and 68 items are flagged as unclear/incomplete. Do not fabricate keys or explanations. Have subject-matter reviewers validate and approve all questions.
- Before real use, add a privacy notice, consent and retention policy, secure receipt storage, server-side timed-session enforcement, audit logging, backups, accessibility testing, penetration/RLS testing, and university sign-off.

## Validation status
The package files and SQL were assembled and reviewed, but a dependency installation/build check could not be completed in this environment because `npm install` timed out. Run `npm install` and `npm run build` in the deployment environment and resolve any dependency/build issues before launch.
