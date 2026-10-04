Marrakech Stay — V9 Index Chat / Navigation Fix

Based on the stable V9 CHAT PRO project.
Only requested changes were made:
- Fixed blank/empty chat on index.html by restoring getMyMessages() compatibility around dbGetMyMessages().
- Raised chat widget/floating button z-index so it stays visible above page content.
- Header: logo left, navigation centered, profile icon right, theme button beside it.
- Removed the top chat icon beside Contact.
- Profile icon opens the existing profile panel instead of logging out.
- Existing profile editing (first name / last name) remains intact.
- Existing light/dark chat design and other V9 features are preserved.

No new Supabase SQL is required for these UI/JS fixes if the existing V9 profile/chat SQL has already been executed.
