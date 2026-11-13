const phone = document.querySelector(".phone")
const reel = document.querySelector(".phone .reel")
const shots = [...document.querySelectorAll(".phone .reel > img")]
const names = ["rounds", "timer", "stop"]

if (phone && reel && shots.length > 1) {
  const clone = shots[0].cloneNode(true)
  clone.alt = ""
  clone.setAttribute("aria-hidden", "true")
  reel.appendChild(clone)

  let index = 0
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches

  function place(position, animate) {
    reel.style.transition = animate ? "" : "none"
    reel.style.transform = `translateX(${-position * 100}%)`
    shots.forEach((img, i) => img.toggleAttribute("aria-hidden", i !== index))
    document.body.dataset.shot = names[index]
  }

  reel.addEventListener("transitionend", (event) => {
    if (event.target !== reel || event.propertyName !== "transform") return
    if (index !== 0) return
    place(0, false)
  })

  place(0, false)

  if (!reduce) {
    setInterval(() => {
      index = (index + 1) % shots.length
      place(index === 0 ? shots.length : index, true)
    }, 4500)
  }
}
