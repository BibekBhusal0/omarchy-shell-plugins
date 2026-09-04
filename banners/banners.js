const SAMPLE = {
  name: "Focusd",
  icon: "app/icon-park-outline--tomato.svg",
  tagline: "A pomodoro timer that keeps score",
  bullets: [
    ["icons/hugeicons--flame.svg", "Streaks and daily goals keep you honest"],
    ["icons/hugeicons--chart-03.svg", "Detailed statistics and history"],
    ["icons/hugeicons--square-terminal.svg", "Bar widget and TUI always in sync"],
  ],
  shot: "screenshot/focusd.png",
  id: "bibek.focusd",
  version: "1.1.1",
};

function addBanner(b) {
  const section = document.createElement("section");
  section.className = "banner";
  section.innerHTML = `
    <div class="overlay"></div>
    <div class="content">
      <div class="left">
        <div class="brand">
          <img src="${b.icon}" alt="${b.name}">
          <h1${b.name.length > 16 ? ' class="small"' : ""}>${b.name}</h1>
        </div>
        <p class="tagline">${b.tagline}</p>
        <ul class="bullets">
          ${b.bullets.map(([icon, text]) => `
            <li>
              <span class="chip">
                <img src="${icon}" alt="">
              </span>
              ${text}
            </li>`).join("")}
        </ul>
      </div>
        <div class="right">
          <div class="shot-frame">
            <img class="shot" src="${b.shot}" alt="${b.name}">
          </div>
        </div>
    </div>
    <div class="footer">${b.id} &middot; v${b.version}</div>`;
  document.getElementById("banners").appendChild(section);
}

const param = new URLSearchParams(location.search).get("banner");
if (param) document.body.style.padding = "0";
addBanner(param ? JSON.parse(param) : SAMPLE);
