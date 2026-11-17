const hook = process.env.ROUND_TIMER_MARKETING_DEPLOY_HOOK;
if (!hook) {
  console.error("ROUND_TIMER_MARKETING_DEPLOY_HOOK is not set");
  process.exit(2);
}

const response = await fetch(hook, { method: "POST" });
const body = await response.text();
console.log(`deploy hook: ${response.status} ${body}`);
if (!response.ok) process.exit(1);