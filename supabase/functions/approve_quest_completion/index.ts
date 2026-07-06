// Supabase Edge Function placeholder for the event-driven reward pipeline.
// Next sprint: validate completion, grant XP/gold, update skills, damage boss, write chronicle.

Deno.serve(async () => {
  return new Response(
    JSON.stringify({ ok: true, message: 'approve_quest_completion placeholder' }),
    { headers: { 'Content-Type': 'application/json' } },
  );
});
