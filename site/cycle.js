const shots = [...document.querySelectorAll(".deck img")]
const names = ["rounds", "timer", "stop"]

if (shots.length > 1) {
  let index = 0
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches

  function show(next) {
    index = next
    shots.forEach((img, i) => {
      const slot = (i - index + shots.length) % shots.length
      img.dataset.slot = String(slot)
      img.toggleAttribute("aria-hidden", slot !== 0)
    })
    document.body.dataset.shot = names[index]
  }

  show(0)

  if (!reduce) {
    setInterval(() => show((index + 1) % shots.length), 4500)
  }
}
