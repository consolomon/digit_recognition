# PageShell

The frame every page lives in (`base.html`): a fixed 2px `ink` frame inset by `frame-inset`, and a scroll window inside it, so content is clipped at the frame line.

- **Body:** `bg` with the network image (`assets/Backgrounds/network_bg.webp`) anchored at the bottom.
- **Inside the window:** the sticky navbar, the page's content block, then the partners footer.
- **Pages:** extend `base.html` and fill `title`, `content` and `scripts`.
- **Preview:** a static rendition, since the real frame is `position: fixed`.
