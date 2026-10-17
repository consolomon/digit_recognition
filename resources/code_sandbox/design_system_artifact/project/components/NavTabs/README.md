# NavTabs

The site navbar: the brand on the left, and four underlined tabs (Stage 1, Stage 2, Stage 3, History) on the right.

- **Where:** it lives once, in `base.html`, sticky at the top of the scroll window. Pages never copy it; they set `active_page`.
- **States:**
  - default: `soft` text with a 1px `line-strong` underline;
  - hover: `ink` text and underline;
  - active: `accent` text with a 2px `accent` underline, plus `aria-current="page"`.
- **Phones:** the tabs wrap under the brand.
