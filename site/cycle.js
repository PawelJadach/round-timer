const shots = [...document.querySelectorAll(".phone img")]
const names = ["rounds", "timer", "stop"]
let index = 0

function show(next) {
  index = next
  shots.forEach((img, i) => {
    const on = i === index
    img.classList.toggle("on", on)
    img.toggleAttribute("aria-hidden", !on)
  })
  document.body.dataset.shot = names[index]
}

show(0)

if (shots.length > 1 && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
  setInterval(() => show((index + 1) % shots.length), 4500)
}
