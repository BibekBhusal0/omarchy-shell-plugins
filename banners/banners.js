const BANNERS = [
  {
    name: "Focusd",
    icon: "app/icon-park-outline--tomato.svg",
    tagline: "A pomodoro timer that keeps score",
    bullets: [
      ["icons/hugeicons--flame.svg", "Streaks and daily goals keep you honest"],
      ["icons/hugeicons--chart-03.svg", "Detailed statistics and history"],
      ["icons/hugeicons--square-terminal.svg", "Bar widget and TUI always in sync"],
    ],
    shot: "screenshot/focusd.png",
    file: "../focusd/preview.png",
  },
  {
    name: "Readest",
    icon: "app/readest.png",
    tagline: "Your whole library, one keystroke away",
    bullets: [
      ["icons/hugeicons--search-01.svg", "Fuzzy search by title or author"],
      ["icons/hugeicons--book-open-01.svg", "Cover art in every result row"],
      ["icons/hugeicons--history.svg", "Most recently opened books first"],
    ],
    shot: "screenshot/readest.png",
    file: "../readest/preview.png",
  },
  {
    name: "Obsidian Search",
    icon: "app/thesvg-color--obsidian.svg",
    tagline: "Find any note. Miss one, it's already created",
    bullets: [
      ["icons/hugeicons--search-01.svg", "Fuzzy search across the whole vault"],
      ["icons/hugeicons--shapes-01.svg", "Bases and canvas files included"],
      ["icons/hugeicons--pencil-edit-01.svg", "No match creates the note for you"],
    ],
    shot: "screenshot/obsidian.png",
    file: "../obsidian-search/preview.png",
  },
  {
    name: "Youtube Video Downloader",
    smallTitle: true,
    icon: "app/logos--youtube-icon.svg",
    tagline: "Copy a link, or don't. It sees what's playing",
    bullets: [
      ["icons/hugeicons--ai-sparkles.svg", "Auto-detects clipboard links and browser playback"],
      ["icons/hugeicons--download-01.svg", "Three parallel downloads, the rest queue up"],
      ["icons/hugeicons--history.svg", "History, playlists and transcripts"],
    ],
    shot: "screenshot/ytdl.png",
    file: "../ytdl/preview.png",
  },
];

function addBanner(b) {
  const section = document.createElement("section");
  section.className = "banner";
  section.innerHTML = `
    <div class="overlay"></div>
    <div class="content">
      <div class="left">
        <div class="brand">
          <img src="${b.icon}" alt="${b.name}">
          <h1${b.smallTitle ? ' class="small"' : ""}>${b.name}</h1>
        </div>
        <p class="tagline">${b.tagline}</p>
        <ul class="bullets">
          ${b.bullets
            .map(
              ([icon, text]) => `
            <li>
              <span class="chip">
                <img src="${icon}" alt="">
              </span>
              ${text}
            </li>`,
            )
            .join("")}
        </ul>
      </div>
      <div class="right">
        <img class="shot" src="${b.shot}" alt="${b.name}">
      </div>
    </div>
    <div class="footer">omarchy plugin &middot; bibek bhusal</div>`;
  document.getElementById("banners").appendChild(section);
}

const only = new URLSearchParams(location.search).get("banner");
const list = only === null ? BANNERS : [BANNERS[Number(only)]].filter(Boolean);
if (only !== null) document.body.style.padding = "0";
list.forEach(addBanner);
