-- Seed wizard recommendations (gender-specific + unisex) for default categories.
-- Each record stores:
-- - unisex: 5 goals (used as: 2-goal addon for gendered users, or full set for prefer_not_to_say)
-- - male/female/non_binary: 3 goals

insert into dv_wizard_recommendations_v2 (
  core_value_id, category_key, gender_key, category_label, recommendations_json, source, created_by
) values

-- growth_mindset / health
('growth_mindset','health','unisex','Health', '{
  "goals":[
    {"name":"Build a consistent sleep routine","whyImportant":"Better sleep improves mood, focus, and energy.","habits":[{"name":"No screens 30 minutes before bed","frequency":"Daily"},{"name":"Set a consistent bedtime","frequency":"Daily"}]},
    {"name":"Move your body every day","whyImportant":"Daily movement keeps energy up and stress down.","habits":[{"name":"20 minute walk","frequency":"Daily"},{"name":"Stretch for 5 minutes","frequency":"Daily"}]},
    {"name":"Eat balanced meals most days","whyImportant":"Balanced nutrition supports long term health.","habits":[{"name":"Add a protein source to meals","frequency":"Daily"},{"name":"Add a fruit or veggie","frequency":"Daily"}]},
    {"name":"Hydrate consistently","whyImportant":"Hydration supports energy and recovery.","habits":[{"name":"Drink a glass of water after waking","frequency":"Daily"},{"name":"Carry a water bottle","frequency":"Daily"}]},
    {"name":"Reduce high sugar snacks","whyImportant":"Stable energy helps you stay consistent.","habits":[{"name":"Swap one snack for fruit or nuts","frequency":"Daily"},{"name":"Plan healthy snacks ahead","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','health','male','Health', '{
  "goals":[
    {"name":"Improve cardiovascular endurance","whyImportant":"Endurance supports daily energy and long term health.","habits":[{"name":"Zone 2 cardio 3 times a week","frequency":"Weekly"},{"name":"Track resting heart rate","frequency":"Weekly"}]},
    {"name":"Build functional strength","whyImportant":"Strength supports posture, confidence, and injury prevention.","habits":[{"name":"Strength workout 3 times a week","frequency":"Weekly"},{"name":"Protein with each main meal","frequency":"Daily"}]},
    {"name":"Schedule a preventive health check","whyImportant":"Prevention catches issues early.","habits":[{"name":"Book annual checkup","frequency":"Weekly"},{"name":"Get basic labs done","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','health','female','Health', '{
  "goals":[
    {"name":"Build sustainable strength training","whyImportant":"Strength supports confidence, bone health, and energy.","habits":[{"name":"Strength workout 2 times a week","frequency":"Weekly"},{"name":"Progress one exercise monthly","frequency":"Weekly"}]},
    {"name":"Improve recovery and stress balance","whyImportant":"Recovery keeps you consistent and prevents burnout.","habits":[{"name":"Wind down routine before bed","frequency":"Daily"},{"name":"Take a 10 minute walk outside","frequency":"Daily"}]},
    {"name":"Prioritize preventive care","whyImportant":"Regular care supports long term wellbeing.","habits":[{"name":"Schedule routine checkups","frequency":"Weekly"},{"name":"Track basic health markers","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','health','non_binary','Health', '{
  "goals":[
    {"name":"Build a daily movement habit","whyImportant":"Movement supports mood and long term health.","habits":[{"name":"20 minutes of movement","frequency":"Daily"},{"name":"Stretch for 5 minutes","frequency":"Daily"}]},
    {"name":"Improve sleep quality","whyImportant":"Better sleep improves focus and resilience.","habits":[{"name":"Consistent bedtime window","frequency":"Daily"},{"name":"No caffeine after mid afternoon","frequency":"Daily"}]},
    {"name":"Eat in a way that supports energy","whyImportant":"Stable energy helps your goals and mindset.","habits":[{"name":"Add a protein source to meals","frequency":"Daily"},{"name":"Plan groceries weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- growth_mindset / learning
('growth_mindset','learning','unisex','Learning', '{
  "goals":[
    {"name":"Read 12 books this year","whyImportant":"Reading expands knowledge and perspective.","habits":[{"name":"Read 15 minutes","frequency":"Daily"},{"name":"Track finished books","frequency":"Weekly"}]},
    {"name":"Learn a new skill","whyImportant":"Skills improve confidence and opportunity.","habits":[{"name":"Practice 20 minutes","frequency":"Daily"},{"name":"Review progress weekly","frequency":"Weekly"}]},
    {"name":"Build a study routine","whyImportant":"Consistency makes learning easy.","habits":[{"name":"Block a daily learning slot","frequency":"Daily"},{"name":"Remove distractions during study","frequency":"Daily"}]},
    {"name":"Take an online course","whyImportant":"Structured learning speeds growth.","habits":[{"name":"Complete 2 lessons weekly","frequency":"Weekly"},{"name":"Take notes and summarize","frequency":"Weekly"}]},
    {"name":"Improve memory with spaced repetition","whyImportant":"Retention accelerates mastery.","habits":[{"name":"Use flashcards for key topics","frequency":"Daily"},{"name":"Weekly review session","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','learning','male','Learning', '{
  "goals":[
    {"name":"Earn a certification","whyImportant":"Credentials can open doors and boost confidence.","habits":[{"name":"Study 30 minutes","frequency":"Daily"},{"name":"Practice exams weekly","frequency":"Weekly"}]},
    {"name":"Improve communication skills","whyImportant":"Clear communication increases impact.","habits":[{"name":"Write a daily summary note","frequency":"Daily"},{"name":"Record and review one talk weekly","frequency":"Weekly"}]},
    {"name":"Build consistent deep work","whyImportant":"Focus helps you learn faster.","habits":[{"name":"One 45 minute deep work block","frequency":"Daily"},{"name":"Plan top 3 tasks","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','learning','female','Learning', '{
  "goals":[
    {"name":"Advance a key professional skill","whyImportant":"Growth increases confidence and opportunity.","habits":[{"name":"Practice 30 minutes","frequency":"Daily"},{"name":"Weekly project milestone","frequency":"Weekly"}]},
    {"name":"Build a reading habit","whyImportant":"Reading improves clarity and creativity.","habits":[{"name":"Read 15 minutes","frequency":"Daily"},{"name":"Share one takeaway weekly","frequency":"Weekly"}]},
    {"name":"Learn through community","whyImportant":"Learning with others keeps motivation high.","habits":[{"name":"Join one study group session","frequency":"Weekly"},{"name":"Ask one question weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','learning','non_binary','Learning', '{
  "goals":[
    {"name":"Learn a new skill you enjoy","whyImportant":"Enjoyment makes learning sustainable.","habits":[{"name":"Practice 20 minutes","frequency":"Daily"},{"name":"Track small wins","frequency":"Weekly"}]},
    {"name":"Strengthen problem solving","whyImportant":"Problem solving improves resilience.","habits":[{"name":"Solve one challenge daily","frequency":"Daily"},{"name":"Review mistakes weekly","frequency":"Weekly"}]},
    {"name":"Build a consistent study routine","whyImportant":"Routine builds momentum without stress.","habits":[{"name":"Block a learning slot","frequency":"Daily"},{"name":"Set a weekly goal","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- growth_mindset / mindfulness
('growth_mindset','mindfulness','unisex','Mindfulness', '{
  "goals":[
    {"name":"Meditate consistently","whyImportant":"Mindfulness builds calm and focus.","habits":[{"name":"5 minute meditation","frequency":"Daily"},{"name":"One mindful pause","frequency":"Daily"}]},
    {"name":"Practice gratitude","whyImportant":"Gratitude improves mood and perspective.","habits":[{"name":"Write 3 gratitude points","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]},
    {"name":"Reduce daily stress","whyImportant":"Lower stress improves health and clarity.","habits":[{"name":"10 minute walk outside","frequency":"Daily"},{"name":"Breathing exercise","frequency":"Daily"}]},
    {"name":"Be present in conversations","whyImportant":"Presence improves connection and confidence.","habits":[{"name":"Phone away during meals","frequency":"Daily"},{"name":"Active listening practice","frequency":"Daily"}]},
    {"name":"Journal for clarity","whyImportant":"Journaling reduces mental noise.","habits":[{"name":"5 minute journal","frequency":"Daily"},{"name":"Weekly review of notes","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','mindfulness','male','Mindfulness', '{
  "goals":[
    {"name":"Build a daily calm routine","whyImportant":"Calm improves decisions and performance.","habits":[{"name":"5 minute breathing","frequency":"Daily"},{"name":"Short walk without phone","frequency":"Daily"}]},
    {"name":"Improve emotional regulation","whyImportant":"Regulation improves relationships and focus.","habits":[{"name":"Label emotions in journal","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]},
    {"name":"Reduce reactive stress","whyImportant":"Less reactivity improves energy and health.","habits":[{"name":"Pause before responding","frequency":"Daily"},{"name":"Evening unwind routine","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','mindfulness','female','Mindfulness', '{
  "goals":[
    {"name":"Protect quiet time daily","whyImportant":"Quiet time supports clarity and self care.","habits":[{"name":"10 minutes of silence","frequency":"Daily"},{"name":"Boundary for notifications","frequency":"Daily"}]},
    {"name":"Build a calming morning routine","whyImportant":"Mornings set the tone for the day.","habits":[{"name":"No phone for first 15 minutes","frequency":"Daily"},{"name":"5 minute meditation","frequency":"Daily"}]},
    {"name":"Reduce overwhelm","whyImportant":"Less overwhelm helps you follow through.","habits":[{"name":"Write top 3 priorities","frequency":"Daily"},{"name":"Weekly planning session","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','mindfulness','non_binary','Mindfulness', '{
  "goals":[
    {"name":"Meditate consistently","whyImportant":"Meditation supports calm and self trust.","habits":[{"name":"5 minute meditation","frequency":"Daily"},{"name":"Mindful breathing pause","frequency":"Daily"}]},
    {"name":"Journal for self clarity","whyImportant":"Journaling reduces stress and confusion.","habits":[{"name":"Write one page or note","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]},
    {"name":"Practice self compassion","whyImportant":"Compassion supports resilience.","habits":[{"name":"Kind self talk check","frequency":"Daily"},{"name":"One small act of self care","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),

-- growth_mindset / confidence
('growth_mindset','confidence','unisex','Confidence', '{
  "goals":[
    {"name":"Speak up more often","whyImportant":"Visibility builds confidence and growth.","habits":[{"name":"Share one idea daily","frequency":"Daily"},{"name":"Weekly review of wins","frequency":"Weekly"}]},
    {"name":"Build a strong self image","whyImportant":"Self image affects choices and action.","habits":[{"name":"Write one strength daily","frequency":"Daily"},{"name":"Practice power posture","frequency":"Daily"}]},
    {"name":"Do hard things consistently","whyImportant":"Challenge builds confidence over time.","habits":[{"name":"One discomfort rep daily","frequency":"Daily"},{"name":"Weekly challenge choice","frequency":"Weekly"}]},
    {"name":"Improve public speaking","whyImportant":"Speaking skills increase influence.","habits":[{"name":"Practice 5 minutes","frequency":"Daily"},{"name":"Record one talk weekly","frequency":"Weekly"}]},
    {"name":"Build social confidence","whyImportant":"Connection improves happiness and growth.","habits":[{"name":"Start one conversation","frequency":"Daily"},{"name":"Plan one social activity","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','confidence','male','Confidence', '{
  "goals":[
    {"name":"Build consistent self discipline","whyImportant":"Discipline increases confidence and results.","habits":[{"name":"Complete top task first","frequency":"Daily"},{"name":"Track habits daily","frequency":"Daily"}]},
    {"name":"Improve social confidence","whyImportant":"Better connection supports growth.","habits":[{"name":"Start one conversation","frequency":"Daily"},{"name":"Weekly social plan","frequency":"Weekly"}]},
    {"name":"Communicate more clearly","whyImportant":"Clarity increases influence.","habits":[{"name":"Write one clear message daily","frequency":"Daily"},{"name":"Weekly feedback request","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','confidence','female','Confidence', '{
  "goals":[
    {"name":"Advocate for yourself","whyImportant":"Advocacy builds confidence and opportunity.","habits":[{"name":"Ask for what you need once a day","frequency":"Daily"},{"name":"Weekly boundary check","frequency":"Weekly"}]},
    {"name":"Build leadership presence","whyImportant":"Presence helps you be heard and respected.","habits":[{"name":"Speak once in meetings","frequency":"Daily"},{"name":"Practice confident posture","frequency":"Daily"}]},
    {"name":"Celebrate progress","whyImportant":"Celebration builds motivation and confidence.","habits":[{"name":"Write one win daily","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('growth_mindset','confidence','non_binary','Confidence', '{
  "goals":[
    {"name":"Build steady self confidence","whyImportant":"Confidence supports better choices and calm.","habits":[{"name":"Write one win daily","frequency":"Daily"},{"name":"Practice confident breathing","frequency":"Daily"}]},
    {"name":"Speak up with clarity","whyImportant":"Clarity helps you feel seen and heard.","habits":[{"name":"Share one idea daily","frequency":"Daily"},{"name":"Weekly practice talk","frequency":"Weekly"}]},
    {"name":"Try one new challenge weekly","whyImportant":"New challenges build resilience.","habits":[{"name":"One discomfort rep daily","frequency":"Daily"},{"name":"Pick a weekly challenge","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- career_ambition / skills
('career_ambition','skills','unisex','Skills', '{
  "goals":[
    {"name":"Improve a core job skill","whyImportant":"Skill growth increases impact and opportunity.","habits":[{"name":"Practice 30 minutes","frequency":"Daily"},{"name":"Weekly project milestone","frequency":"Weekly"}]},
    {"name":"Build deep work habits","whyImportant":"Focus improves output and learning speed.","habits":[{"name":"One 45 minute focus block","frequency":"Daily"},{"name":"Plan tomorrow today","frequency":"Daily"}]},
    {"name":"Learn better communication","whyImportant":"Communication improves teamwork and leadership.","habits":[{"name":"Write one clear message daily","frequency":"Daily"},{"name":"Weekly feedback request","frequency":"Weekly"}]},
    {"name":"Grow technical ability","whyImportant":"Technical skills increase leverage.","habits":[{"name":"Practice one concept daily","frequency":"Daily"},{"name":"Build one small project weekly","frequency":"Weekly"}]},
    {"name":"Improve time management","whyImportant":"Better planning reduces stress and increases results.","habits":[{"name":"Set top 3 priorities","frequency":"Daily"},{"name":"Weekly planning session","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','skills','male','Skills', '{
  "goals":[
    {"name":"Master a high leverage skill","whyImportant":"Leverage skills create career momentum.","habits":[{"name":"Practice 45 minutes","frequency":"Daily"},{"name":"Weekly progress review","frequency":"Weekly"}]},
    {"name":"Improve negotiation","whyImportant":"Negotiation increases career and income outcomes.","habits":[{"name":"Practice one script daily","frequency":"Daily"},{"name":"Weekly role play","frequency":"Weekly"}]},
    {"name":"Build consistent execution","whyImportant":"Execution is what creates results.","habits":[{"name":"Daily top task first","frequency":"Daily"},{"name":"Weekly goals checklist","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','skills','female','Skills', '{
  "goals":[
    {"name":"Strengthen leadership skills","whyImportant":"Leadership increases influence and growth.","habits":[{"name":"Weekly leadership lesson","frequency":"Weekly"},{"name":"Mentor or learn from a mentor","frequency":"Weekly"}]},
    {"name":"Improve communication confidence","whyImportant":"Clear communication increases impact.","habits":[{"name":"Speak once in meetings","frequency":"Daily"},{"name":"Weekly practice presentation","frequency":"Weekly"}]},
    {"name":"Build a strong portfolio","whyImportant":"A portfolio makes your work visible.","habits":[{"name":"Document one win weekly","frequency":"Weekly"},{"name":"Update portfolio monthly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','skills','non_binary','Skills', '{
  "goals":[
    {"name":"Build a skill practice routine","whyImportant":"Routine makes growth automatic.","habits":[{"name":"Practice 30 minutes","frequency":"Daily"},{"name":"Weekly review","frequency":"Weekly"}]},
    {"name":"Improve problem solving","whyImportant":"Problem solving increases confidence and results.","habits":[{"name":"Solve one challenge daily","frequency":"Daily"},{"name":"Reflect weekly","frequency":"Weekly"}]},
    {"name":"Develop better focus","whyImportant":"Focus multiplies the value of your time.","habits":[{"name":"One distraction free block","frequency":"Daily"},{"name":"Plan top 3 priorities","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),

-- career_ambition / promotion
('career_ambition','promotion','unisex','Promotion', '{
  "goals":[
    {"name":"Get promoted this year","whyImportant":"Promotion reflects impact and growth.","habits":[{"name":"Weekly impact log","frequency":"Weekly"},{"name":"Align priorities with manager","frequency":"Weekly"}]},
    {"name":"Increase visibility at work","whyImportant":"Visibility helps opportunities find you.","habits":[{"name":"Share progress weekly","frequency":"Weekly"},{"name":"Speak up in meetings","frequency":"Daily"}]},
    {"name":"Deliver a key project","whyImportant":"Projects prove your ability to lead and execute.","habits":[{"name":"Plan next milestone","frequency":"Weekly"},{"name":"Daily progress step","frequency":"Daily"}]},
    {"name":"Improve stakeholder communication","whyImportant":"Good communication builds trust.","habits":[{"name":"Weekly status update","frequency":"Weekly"},{"name":"Clarify expectations early","frequency":"Weekly"}]},
    {"name":"Build stronger relationships with leaders","whyImportant":"Relationships improve alignment and sponsorship.","habits":[{"name":"One 1:1 connection weekly","frequency":"Weekly"},{"name":"Offer help proactively","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','promotion','male','Promotion', '{
  "goals":[
    {"name":"Lead a high impact initiative","whyImportant":"Leadership accelerates promotion readiness.","habits":[{"name":"Weekly initiative update","frequency":"Weekly"},{"name":"Daily priority execution","frequency":"Daily"}]},
    {"name":"Improve executive communication","whyImportant":"Clear updates increase trust and visibility.","habits":[{"name":"Write concise updates weekly","frequency":"Weekly"},{"name":"Practice 2 minute summary","frequency":"Weekly"}]},
    {"name":"Expand your scope","whyImportant":"Scope growth is a promotion signal.","habits":[{"name":"Take on one stretch task weekly","frequency":"Weekly"},{"name":"Weekly planning with manager","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','promotion','female','Promotion', '{
  "goals":[
    {"name":"Build a promotion plan","whyImportant":"Clarity makes progress measurable.","habits":[{"name":"Weekly impact log","frequency":"Weekly"},{"name":"Monthly goals checkin","frequency":"Weekly"}]},
    {"name":"Strengthen sponsorship","whyImportant":"Sponsors help your work get recognized.","habits":[{"name":"Schedule one relationship checkin","frequency":"Weekly"},{"name":"Share wins weekly","frequency":"Weekly"}]},
    {"name":"Lead confidently in meetings","whyImportant":"Presence improves influence.","habits":[{"name":"Speak once per meeting","frequency":"Daily"},{"name":"Prepare key points","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','promotion','non_binary','Promotion', '{
  "goals":[
    {"name":"Grow your impact at work","whyImportant":"Impact is the path to advancement.","habits":[{"name":"Weekly impact log","frequency":"Weekly"},{"name":"Daily progress step","frequency":"Daily"}]},
    {"name":"Increase visibility","whyImportant":"Visibility helps opportunities and recognition.","habits":[{"name":"Share progress weekly","frequency":"Weekly"},{"name":"Speak up once daily","frequency":"Daily"}]},
    {"name":"Build a clear promotion roadmap","whyImportant":"A roadmap keeps you consistent.","habits":[{"name":"Weekly checkin on goals","frequency":"Weekly"},{"name":"Monthly feedback request","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- career_ambition / income
('career_ambition','income','unisex','Income', '{
  "goals":[
    {"name":"Increase income","whyImportant":"More income supports freedom and security.","habits":[{"name":"Track spending weekly","frequency":"Weekly"},{"name":"Apply to one opportunity weekly","frequency":"Weekly"}]},
    {"name":"Build an emergency fund","whyImportant":"Savings reduces stress and improves choices.","habits":[{"name":"Auto save weekly","frequency":"Weekly"},{"name":"Review budget weekly","frequency":"Weekly"}]},
    {"name":"Start investing consistently","whyImportant":"Investing compounds over time.","habits":[{"name":"Auto invest monthly","frequency":"Weekly"},{"name":"Learn one investing concept weekly","frequency":"Weekly"}]},
    {"name":"Reduce unnecessary expenses","whyImportant":"Lower expenses increase flexibility.","habits":[{"name":"No spend day","frequency":"Weekly"},{"name":"Plan purchases","frequency":"Weekly"}]},
    {"name":"Build a side income stream","whyImportant":"Side income creates options.","habits":[{"name":"Work on side project weekly","frequency":"Weekly"},{"name":"Weekly outreach","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','income','male','Income', '{
  "goals":[
    {"name":"Negotiate a raise","whyImportant":"Negotiation can significantly increase earnings.","habits":[{"name":"Document wins weekly","frequency":"Weekly"},{"name":"Practice negotiation script","frequency":"Weekly"}]},
    {"name":"Build a side income project","whyImportant":"Side projects diversify income.","habits":[{"name":"2 hours weekly on side project","frequency":"Weekly"},{"name":"Weekly outreach","frequency":"Weekly"}]},
    {"name":"Improve financial discipline","whyImportant":"Discipline builds long term freedom.","habits":[{"name":"Track spending weekly","frequency":"Weekly"},{"name":"Save automatically","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','income','female','Income', '{
  "goals":[
    {"name":"Increase earning potential","whyImportant":"Higher income increases freedom and security.","habits":[{"name":"Learn a high value skill weekly","frequency":"Weekly"},{"name":"Apply to one opportunity weekly","frequency":"Weekly"}]},
    {"name":"Negotiate confidently","whyImportant":"Negotiation supports fair compensation.","habits":[{"name":"Track achievements weekly","frequency":"Weekly"},{"name":"Practice negotiation script","frequency":"Weekly"}]},
    {"name":"Build consistent savings","whyImportant":"Savings reduces stress and increases choices.","habits":[{"name":"Auto save weekly","frequency":"Weekly"},{"name":"Review budget weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','income','non_binary','Income', '{
  "goals":[
    {"name":"Build steady savings","whyImportant":"Savings improves freedom and stability.","habits":[{"name":"Auto save weekly","frequency":"Weekly"},{"name":"Weekly budget check","frequency":"Weekly"}]},
    {"name":"Grow income with new opportunities","whyImportant":"Opportunities create momentum and options.","habits":[{"name":"Apply to one opportunity weekly","frequency":"Weekly"},{"name":"Weekly networking","frequency":"Weekly"}]},
    {"name":"Start investing consistently","whyImportant":"Investing compounds for the future.","habits":[{"name":"Auto invest monthly","frequency":"Weekly"},{"name":"Learn one concept weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- career_ambition / leadership
('career_ambition','leadership','unisex','Leadership', '{
  "goals":[
    {"name":"Lead with clarity","whyImportant":"Clarity improves outcomes and trust.","habits":[{"name":"Write weekly priorities","frequency":"Weekly"},{"name":"Daily 2 minute plan","frequency":"Daily"}]},
    {"name":"Become a better mentor","whyImportant":"Mentoring builds leadership and community.","habits":[{"name":"One mentoring touchpoint weekly","frequency":"Weekly"},{"name":"Share feedback kindly","frequency":"Weekly"}]},
    {"name":"Build strong team communication","whyImportant":"Communication reduces friction and builds trust.","habits":[{"name":"Weekly team update","frequency":"Weekly"},{"name":"Ask one clarifying question daily","frequency":"Daily"}]},
    {"name":"Improve decision making","whyImportant":"Good decisions create momentum.","habits":[{"name":"Document decisions weekly","frequency":"Weekly"},{"name":"Review outcomes monthly","frequency":"Weekly"}]},
    {"name":"Develop emotional intelligence","whyImportant":"EQ improves leadership and relationships.","habits":[{"name":"Pause before responding","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','leadership','male','Leadership', '{
  "goals":[
    {"name":"Become a trusted leader","whyImportant":"Trust enables impact and influence.","habits":[{"name":"Weekly 1:1s","frequency":"Weekly"},{"name":"Deliver on commitments","frequency":"Daily"}]},
    {"name":"Improve coaching skills","whyImportant":"Coaching helps others grow and perform.","habits":[{"name":"Give one piece of feedback weekly","frequency":"Weekly"},{"name":"Ask coaching questions daily","frequency":"Daily"}]},
    {"name":"Lead projects end to end","whyImportant":"Ownership is a leadership signal.","habits":[{"name":"Weekly milestone planning","frequency":"Weekly"},{"name":"Daily progress step","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','leadership','female','Leadership', '{
  "goals":[
    {"name":"Grow leadership presence","whyImportant":"Presence improves influence and clarity.","habits":[{"name":"Speak once in meetings","frequency":"Daily"},{"name":"Weekly practice talk","frequency":"Weekly"}]},
    {"name":"Build confident delegation","whyImportant":"Delegation increases scale and results.","habits":[{"name":"Delegate one task weekly","frequency":"Weekly"},{"name":"Weekly follow up","frequency":"Weekly"}]},
    {"name":"Strengthen mentoring","whyImportant":"Mentoring builds community and leadership skill.","habits":[{"name":"One mentoring touchpoint weekly","frequency":"Weekly"},{"name":"Share knowledge weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('career_ambition','leadership','non_binary','Leadership', '{
  "goals":[
    {"name":"Lead with empathy","whyImportant":"Empathy builds trust and team strength.","habits":[{"name":"Ask how people are doing","frequency":"Daily"},{"name":"Weekly 1:1s","frequency":"Weekly"}]},
    {"name":"Improve communication clarity","whyImportant":"Clarity reduces stress and confusion.","habits":[{"name":"Weekly written update","frequency":"Weekly"},{"name":"Ask one clarifying question daily","frequency":"Daily"}]},
    {"name":"Build consistent ownership","whyImportant":"Ownership builds credibility and impact.","habits":[{"name":"Daily progress step","frequency":"Daily"},{"name":"Weekly planning","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- creativity_expression / art
('creativity_expression','art','unisex','Art', '{
  "goals":[
    {"name":"Create art weekly","whyImportant":"Art builds expression and joy.","habits":[{"name":"30 minutes of creating","frequency":"Weekly"},{"name":"Save one idea list","frequency":"Weekly"}]},
    {"name":"Improve drawing basics","whyImportant":"Basics make creativity easier.","habits":[{"name":"Sketch daily","frequency":"Daily"},{"name":"Study one reference weekly","frequency":"Weekly"}]},
    {"name":"Build a personal style","whyImportant":"Style makes work feel like you.","habits":[{"name":"Collect inspiration weekly","frequency":"Weekly"},{"name":"Experiment with one technique weekly","frequency":"Weekly"}]},
    {"name":"Share your work","whyImportant":"Sharing builds confidence and connection.","habits":[{"name":"Post one piece weekly","frequency":"Weekly"},{"name":"Ask for feedback weekly","frequency":"Weekly"}]},
    {"name":"Finish more pieces","whyImportant":"Finished work builds momentum.","habits":[{"name":"Set a weekly finish goal","frequency":"Weekly"},{"name":"Work in small sessions","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','art','male','Art', '{
  "goals":[
    {"name":"Build a weekly art practice","whyImportant":"Practice builds skill and confidence.","habits":[{"name":"Create 2 times a week","frequency":"Weekly"},{"name":"Study one technique weekly","frequency":"Weekly"}]},
    {"name":"Finish one piece each month","whyImportant":"Finishing builds momentum.","habits":[{"name":"Weekly progress step","frequency":"Weekly"},{"name":"Plan next session","frequency":"Weekly"}]},
    {"name":"Share your work publicly","whyImportant":"Sharing grows confidence and community.","habits":[{"name":"Post weekly","frequency":"Weekly"},{"name":"Reflect on feedback","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','art','female','Art', '{
  "goals":[
    {"name":"Create art for joy","whyImportant":"Joyful practice makes creativity sustainable.","habits":[{"name":"20 minutes of creating","frequency":"Weekly"},{"name":"Collect inspiration","frequency":"Weekly"}]},
    {"name":"Develop a signature style","whyImportant":"Style helps your work stand out.","habits":[{"name":"Experiment weekly","frequency":"Weekly"},{"name":"Save a mood board","frequency":"Weekly"}]},
    {"name":"Build confidence sharing art","whyImportant":"Sharing creates connection and growth.","habits":[{"name":"Share one piece weekly","frequency":"Weekly"},{"name":"Celebrate one win weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','art','non_binary','Art', '{
  "goals":[
    {"name":"Create art consistently","whyImportant":"Consistency strengthens expression.","habits":[{"name":"Create once weekly","frequency":"Weekly"},{"name":"Keep an idea list","frequency":"Weekly"}]},
    {"name":"Improve fundamentals","whyImportant":"Fundamentals increase freedom.","habits":[{"name":"Sketch daily","frequency":"Daily"},{"name":"Study reference weekly","frequency":"Weekly"}]},
    {"name":"Finish small projects","whyImportant":"Finishing builds confidence.","habits":[{"name":"Weekly finish goal","frequency":"Weekly"},{"name":"Work in small sessions","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),

-- creativity_expression / writing
('creativity_expression','writing','unisex','Writing', '{
  "goals":[
    {"name":"Write daily","whyImportant":"Daily writing improves clarity and creativity.","habits":[{"name":"Write 200 words","frequency":"Daily"},{"name":"Weekly review","frequency":"Weekly"}]},
    {"name":"Finish a short story or essay","whyImportant":"Finishing builds momentum.","habits":[{"name":"Outline weekly","frequency":"Weekly"},{"name":"Draft in small sessions","frequency":"Daily"}]},
    {"name":"Publish writing online","whyImportant":"Publishing builds confidence and audience.","habits":[{"name":"Post weekly","frequency":"Weekly"},{"name":"Edit one piece weekly","frequency":"Weekly"}]},
    {"name":"Improve storytelling","whyImportant":"Storytelling increases impact.","habits":[{"name":"Study one story weekly","frequency":"Weekly"},{"name":"Write one scene weekly","frequency":"Weekly"}]},
    {"name":"Build a writing portfolio","whyImportant":"A portfolio makes work visible.","habits":[{"name":"Save best pieces weekly","frequency":"Weekly"},{"name":"Update portfolio monthly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','writing','male','Writing', '{
  "goals":[
    {"name":"Write consistently","whyImportant":"Consistency builds skill and voice.","habits":[{"name":"Write 15 minutes","frequency":"Daily"},{"name":"Weekly review","frequency":"Weekly"}]},
    {"name":"Publish an article","whyImportant":"Publishing builds credibility.","habits":[{"name":"Draft weekly","frequency":"Weekly"},{"name":"Edit weekly","frequency":"Weekly"}]},
    {"name":"Improve clarity and structure","whyImportant":"Clear writing increases influence.","habits":[{"name":"Outline before writing","frequency":"Weekly"},{"name":"Rewrite one paragraph daily","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','writing','female','Writing', '{
  "goals":[
    {"name":"Build a daily writing habit","whyImportant":"Habit makes creativity easy.","habits":[{"name":"Write 200 words","frequency":"Daily"},{"name":"Track streak weekly","frequency":"Weekly"}]},
    {"name":"Finish and share a piece","whyImportant":"Sharing builds confidence.","habits":[{"name":"Draft weekly","frequency":"Weekly"},{"name":"Publish monthly","frequency":"Weekly"}]},
    {"name":"Develop your voice","whyImportant":"Voice makes writing unique.","habits":[{"name":"Free write weekly","frequency":"Weekly"},{"name":"Read great writing weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','writing','non_binary','Writing', '{
  "goals":[
    {"name":"Write for self expression","whyImportant":"Expression builds clarity and confidence.","habits":[{"name":"Write 15 minutes","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]},
    {"name":"Finish a small writing project","whyImportant":"Finishing builds momentum.","habits":[{"name":"Outline weekly","frequency":"Weekly"},{"name":"Draft daily","frequency":"Daily"}]},
    {"name":"Share writing with others","whyImportant":"Sharing creates connection.","habits":[{"name":"Post weekly","frequency":"Weekly"},{"name":"Ask for feedback weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- creativity_expression / music
('creativity_expression','music','unisex','Music', '{
  "goals":[
    {"name":"Practice an instrument regularly","whyImportant":"Practice builds skill and joy.","habits":[{"name":"Practice 20 minutes","frequency":"Daily"},{"name":"Weekly review","frequency":"Weekly"}]},
    {"name":"Learn new songs","whyImportant":"New songs keep motivation high.","habits":[{"name":"Learn one section weekly","frequency":"Weekly"},{"name":"Daily practice","frequency":"Daily"}]},
    {"name":"Record your progress","whyImportant":"Recording shows growth and builds confidence.","habits":[{"name":"Record weekly","frequency":"Weekly"},{"name":"Listen and note improvements","frequency":"Weekly"}]},
    {"name":"Improve rhythm and timing","whyImportant":"Timing improves musicality.","habits":[{"name":"Metronome practice","frequency":"Daily"},{"name":"Clap rhythm drills","frequency":"Weekly"}]},
    {"name":"Perform for friends or online","whyImportant":"Performance builds confidence.","habits":[{"name":"Practice performance set weekly","frequency":"Weekly"},{"name":"Share a clip monthly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','music','male','Music', '{
  "goals":[
    {"name":"Practice music consistently","whyImportant":"Consistency builds skill.","habits":[{"name":"Practice 20 minutes","frequency":"Daily"},{"name":"Weekly goal setting","frequency":"Weekly"}]},
    {"name":"Record a cover","whyImportant":"Recording builds confidence and skill.","habits":[{"name":"Record weekly","frequency":"Weekly"},{"name":"Review and improve","frequency":"Weekly"}]},
    {"name":"Improve rhythm and timing","whyImportant":"Timing improves performance.","habits":[{"name":"Metronome practice","frequency":"Daily"},{"name":"Rhythm drills weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','music','female','Music', '{
  "goals":[
    {"name":"Build a joyful practice habit","whyImportant":"Joy keeps music sustainable.","habits":[{"name":"Practice 15 minutes","frequency":"Daily"},{"name":"Play for fun weekly","frequency":"Weekly"}]},
    {"name":"Learn and perform a song","whyImportant":"Performance builds confidence.","habits":[{"name":"Learn one section weekly","frequency":"Weekly"},{"name":"Practice daily","frequency":"Daily"}]},
    {"name":"Share your progress","whyImportant":"Sharing creates connection.","habits":[{"name":"Record a short clip weekly","frequency":"Weekly"},{"name":"Celebrate wins weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','music','non_binary','Music', '{
  "goals":[
    {"name":"Practice consistently","whyImportant":"Consistency builds musical freedom.","habits":[{"name":"Practice 20 minutes","frequency":"Daily"},{"name":"Weekly review","frequency":"Weekly"}]},
    {"name":"Learn new songs","whyImportant":"New songs keep motivation strong.","habits":[{"name":"Learn one section weekly","frequency":"Weekly"},{"name":"Daily practice","frequency":"Daily"}]},
    {"name":"Record and reflect","whyImportant":"Reflection makes growth visible.","habits":[{"name":"Record weekly","frequency":"Weekly"},{"name":"Note improvements weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- creativity_expression / content
('creativity_expression','content','unisex','Content', '{
  "goals":[
    {"name":"Create content consistently","whyImportant":"Consistency builds an audience.","habits":[{"name":"Post 2 times weekly","frequency":"Weekly"},{"name":"Batch ideas weekly","frequency":"Weekly"}]},
    {"name":"Improve content quality","whyImportant":"Quality builds trust and retention.","habits":[{"name":"Review analytics weekly","frequency":"Weekly"},{"name":"Upgrade one small thing weekly","frequency":"Weekly"}]},
    {"name":"Find your niche","whyImportant":"A niche makes growth easier.","habits":[{"name":"Test one idea weekly","frequency":"Weekly"},{"name":"Capture feedback weekly","frequency":"Weekly"}]},
    {"name":"Build a content library","whyImportant":"A library creates long term value.","habits":[{"name":"Write 3 ideas weekly","frequency":"Weekly"},{"name":"Repurpose one post weekly","frequency":"Weekly"}]},
    {"name":"Grow engagement","whyImportant":"Engagement creates community.","habits":[{"name":"Reply to comments daily","frequency":"Daily"},{"name":"Ask one question weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','content','male','Content', '{
  "goals":[
    {"name":"Post consistently","whyImportant":"Consistency builds reach.","habits":[{"name":"Post weekly","frequency":"Weekly"},{"name":"Batch ideas weekly","frequency":"Weekly"}]},
    {"name":"Improve storytelling","whyImportant":"Storytelling increases engagement.","habits":[{"name":"Outline content weekly","frequency":"Weekly"},{"name":"Study one creator weekly","frequency":"Weekly"}]},
    {"name":"Grow engagement","whyImportant":"Engagement creates community.","habits":[{"name":"Reply daily","frequency":"Daily"},{"name":"Ask one question weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','content','female','Content', '{
  "goals":[
    {"name":"Build a consistent posting rhythm","whyImportant":"Rhythm reduces stress and increases output.","habits":[{"name":"Post 2 times weekly","frequency":"Weekly"},{"name":"Batch create weekly","frequency":"Weekly"}]},
    {"name":"Improve content confidence","whyImportant":"Confidence makes creation easier.","habits":[{"name":"Share one imperfect post weekly","frequency":"Weekly"},{"name":"Celebrate one win weekly","frequency":"Weekly"}]},
    {"name":"Grow a supportive audience","whyImportant":"Community makes creation rewarding.","habits":[{"name":"Engage daily","frequency":"Daily"},{"name":"Weekly community post","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('creativity_expression','content','non_binary','Content', '{
  "goals":[
    {"name":"Create content consistently","whyImportant":"Consistency builds momentum.","habits":[{"name":"Post weekly","frequency":"Weekly"},{"name":"Batch ideas weekly","frequency":"Weekly"}]},
    {"name":"Find a niche you enjoy","whyImportant":"Enjoyment supports long term growth.","habits":[{"name":"Test one topic weekly","frequency":"Weekly"},{"name":"Capture ideas daily","frequency":"Daily"}]},
    {"name":"Improve quality over time","whyImportant":"Small improvements compound.","habits":[{"name":"Review weekly","frequency":"Weekly"},{"name":"Upgrade one thing weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- lifestyle_adventure / travel
('lifestyle_adventure','travel','unisex','Travel', '{
  "goals":[
    {"name":"Plan a dream trip","whyImportant":"Travel creates memories and perspective.","habits":[{"name":"Save weekly for travel","frequency":"Weekly"},{"name":"Research 30 minutes weekly","frequency":"Weekly"}]},
    {"name":"Travel more locally","whyImportant":"Local trips keep adventure affordable.","habits":[{"name":"Plan one day trip monthly","frequency":"Weekly"},{"name":"Explore a new place weekly","frequency":"Weekly"}]},
    {"name":"Create a travel bucket list","whyImportant":"A list keeps motivation clear.","habits":[{"name":"Add one place weekly","frequency":"Weekly"},{"name":"Share plans with a friend","frequency":"Weekly"}]},
    {"name":"Build a travel fund","whyImportant":"Funding makes trips possible.","habits":[{"name":"Auto save weekly","frequency":"Weekly"},{"name":"Cut one expense weekly","frequency":"Weekly"}]},
    {"name":"Capture travel memories","whyImportant":"Memories reinforce meaning.","habits":[{"name":"Take 5 photos on trips","frequency":"Weekly"},{"name":"Write a short travel note","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','travel','male','Travel', '{
  "goals":[
    {"name":"Take a new trip this year","whyImportant":"New places create growth and memories.","habits":[{"name":"Save weekly","frequency":"Weekly"},{"name":"Plan one booking step weekly","frequency":"Weekly"}]},
    {"name":"Try adventure experiences","whyImportant":"Adventure builds confidence and energy.","habits":[{"name":"Research experiences weekly","frequency":"Weekly"},{"name":"Book one activity monthly","frequency":"Weekly"}]},
    {"name":"Travel lighter and simpler","whyImportant":"Simplicity reduces stress on trips.","habits":[{"name":"Pack a simple list","frequency":"Weekly"},{"name":"Plan essentials only","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','travel','female','Travel', '{
  "goals":[
    {"name":"Plan a dream trip","whyImportant":"Travel creates joy and perspective.","habits":[{"name":"Save weekly","frequency":"Weekly"},{"name":"Research weekly","frequency":"Weekly"}]},
    {"name":"Take more weekend trips","whyImportant":"Small trips keep life exciting.","habits":[{"name":"Plan one weekend trip quarterly","frequency":"Weekly"},{"name":"Explore locally weekly","frequency":"Weekly"}]},
    {"name":"Create a travel memory journal","whyImportant":"Journaling captures meaning.","habits":[{"name":"Write one travel note weekly","frequency":"Weekly"},{"name":"Save photos weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','travel','non_binary','Travel', '{
  "goals":[
    {"name":"Plan more travel experiences","whyImportant":"Experiences create energy and memories.","habits":[{"name":"Save weekly for travel","frequency":"Weekly"},{"name":"Research weekly","frequency":"Weekly"}]},
    {"name":"Explore locally","whyImportant":"Local exploration keeps adventure easy.","habits":[{"name":"Try a new spot weekly","frequency":"Weekly"},{"name":"Plan a day trip monthly","frequency":"Weekly"}]},
    {"name":"Build a travel bucket list","whyImportant":"A list keeps you inspired.","habits":[{"name":"Add one destination weekly","frequency":"Weekly"},{"name":"Share plans weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- lifestyle_adventure / fitness
('lifestyle_adventure','fitness','unisex','Fitness', '{
  "goals":[
    {"name":"Work out consistently","whyImportant":"Consistency improves health and confidence.","habits":[{"name":"Workout 3 times weekly","frequency":"Weekly"},{"name":"Daily steps goal","frequency":"Daily"}]},
    {"name":"Improve flexibility and mobility","whyImportant":"Mobility reduces pain and improves movement.","habits":[{"name":"Stretch 5 minutes daily","frequency":"Daily"},{"name":"Mobility session weekly","frequency":"Weekly"}]},
    {"name":"Build strength","whyImportant":"Strength supports energy and resilience.","habits":[{"name":"Strength workout weekly","frequency":"Weekly"},{"name":"Protein with meals","frequency":"Daily"}]},
    {"name":"Improve endurance","whyImportant":"Endurance supports daily life and health.","habits":[{"name":"Cardio 2 times weekly","frequency":"Weekly"},{"name":"One long walk weekly","frequency":"Weekly"}]},
    {"name":"Create a sustainable routine","whyImportant":"A routine reduces decision fatigue.","habits":[{"name":"Schedule workouts","frequency":"Weekly"},{"name":"Prepare workout clothes","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','fitness','male','Fitness', '{
  "goals":[
    {"name":"Build strength consistently","whyImportant":"Strength supports confidence and health.","habits":[{"name":"Strength workout 3 times weekly","frequency":"Weekly"},{"name":"Track lifts weekly","frequency":"Weekly"}]},
    {"name":"Improve endurance","whyImportant":"Endurance supports energy and recovery.","habits":[{"name":"Cardio 2 times weekly","frequency":"Weekly"},{"name":"Daily steps goal","frequency":"Daily"}]},
    {"name":"Improve mobility","whyImportant":"Mobility prevents injury.","habits":[{"name":"Stretch daily","frequency":"Daily"},{"name":"Mobility session weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','fitness','female','Fitness', '{
  "goals":[
    {"name":"Build strength and confidence","whyImportant":"Strength supports energy and wellbeing.","habits":[{"name":"Strength workout 2 times weekly","frequency":"Weekly"},{"name":"Track progress weekly","frequency":"Weekly"}]},
    {"name":"Improve daily movement","whyImportant":"Movement supports mood and health.","habits":[{"name":"Daily steps goal","frequency":"Daily"},{"name":"Walk outside daily","frequency":"Daily"}]},
    {"name":"Create a sustainable routine","whyImportant":"Routine keeps you consistent.","habits":[{"name":"Schedule workouts weekly","frequency":"Weekly"},{"name":"Prepare clothes the night before","frequency":"Daily"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','fitness','non_binary','Fitness', '{
  "goals":[
    {"name":"Build a steady workout habit","whyImportant":"Habit builds health and confidence.","habits":[{"name":"Workout 3 times weekly","frequency":"Weekly"},{"name":"Daily steps goal","frequency":"Daily"}]},
    {"name":"Improve mobility and flexibility","whyImportant":"Mobility supports comfort and movement.","habits":[{"name":"Stretch daily","frequency":"Daily"},{"name":"Mobility session weekly","frequency":"Weekly"}]},
    {"name":"Increase endurance","whyImportant":"Endurance improves energy and resilience.","habits":[{"name":"Cardio twice weekly","frequency":"Weekly"},{"name":"Long walk weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- lifestyle_adventure / experiences
('lifestyle_adventure','experiences','unisex','Experiences', '{
  "goals":[
    {"name":"Try new experiences monthly","whyImportant":"New experiences keep life exciting.","habits":[{"name":"Plan one new activity monthly","frequency":"Weekly"},{"name":"Invite a friend weekly","frequency":"Weekly"}]},
    {"name":"Create more joyful moments","whyImportant":"Joy improves wellbeing.","habits":[{"name":"Do one fun thing weekly","frequency":"Weekly"},{"name":"Capture one memory weekly","frequency":"Weekly"}]},
    {"name":"Attend live events","whyImportant":"Live events create energy and memories.","habits":[{"name":"Browse events weekly","frequency":"Weekly"},{"name":"Book one event monthly","frequency":"Weekly"}]},
    {"name":"Learn a new hobby","whyImportant":"Hobbies build creativity and balance.","habits":[{"name":"Practice hobby weekly","frequency":"Weekly"},{"name":"Watch one tutorial weekly","frequency":"Weekly"}]},
    {"name":"Spend more time outdoors","whyImportant":"Outdoors improves mood and energy.","habits":[{"name":"Outdoor walk daily","frequency":"Daily"},{"name":"Weekend outdoor plan","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','experiences','male','Experiences', '{
  "goals":[
    {"name":"Plan monthly adventures","whyImportant":"Adventures build memories and energy.","habits":[{"name":"Plan one activity weekly","frequency":"Weekly"},{"name":"Book monthly","frequency":"Weekly"}]},
    {"name":"Try a new hobby","whyImportant":"Hobbies add balance and joy.","habits":[{"name":"Practice weekly","frequency":"Weekly"},{"name":"Learn weekly","frequency":"Weekly"}]},
    {"name":"Spend more time outdoors","whyImportant":"Outdoors improves mood and health.","habits":[{"name":"Outdoor walk daily","frequency":"Daily"},{"name":"Weekend plan weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','experiences','female','Experiences', '{
  "goals":[
    {"name":"Create more joyful experiences","whyImportant":"Joy improves wellbeing and motivation.","habits":[{"name":"Do one fun thing weekly","frequency":"Weekly"},{"name":"Plan a monthly outing","frequency":"Weekly"}]},
    {"name":"Explore new places locally","whyImportant":"Exploration keeps life exciting.","habits":[{"name":"Try a new cafe or park weekly","frequency":"Weekly"},{"name":"Invite a friend monthly","frequency":"Weekly"}]},
    {"name":"Attend live events","whyImportant":"Events create memorable moments.","habits":[{"name":"Browse events weekly","frequency":"Weekly"},{"name":"Book one event monthly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','experiences','non_binary','Experiences', '{
  "goals":[
    {"name":"Try something new monthly","whyImportant":"New experiences expand perspective.","habits":[{"name":"Plan one activity weekly","frequency":"Weekly"},{"name":"Book monthly","frequency":"Weekly"}]},
    {"name":"Create more moments of joy","whyImportant":"Joy improves balance and health.","habits":[{"name":"One fun thing weekly","frequency":"Weekly"},{"name":"Capture a memory weekly","frequency":"Weekly"}]},
    {"name":"Spend time outdoors","whyImportant":"Outdoors improves mood.","habits":[{"name":"Outdoor walk daily","frequency":"Daily"},{"name":"Weekend outdoor plan","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- lifestyle_adventure / home
('lifestyle_adventure','home','unisex','Home', '{
  "goals":[
    {"name":"Create a cozy home space","whyImportant":"A cozy space supports calm and wellbeing.","habits":[{"name":"Tidy for 10 minutes","frequency":"Daily"},{"name":"Declutter one area weekly","frequency":"Weekly"}]},
    {"name":"Declutter and organize","whyImportant":"Less clutter reduces stress.","habits":[{"name":"One small declutter daily","frequency":"Daily"},{"name":"Donate items weekly","frequency":"Weekly"}]},
    {"name":"Improve home aesthetics","whyImportant":"A beautiful space supports motivation.","habits":[{"name":"Add one small improvement weekly","frequency":"Weekly"},{"name":"Clean one area weekly","frequency":"Weekly"}]},
    {"name":"Build a relaxing routine at home","whyImportant":"Home should feel restorative.","habits":[{"name":"Evening reset routine","frequency":"Daily"},{"name":"Light a candle or play calm music","frequency":"Daily"}]},
    {"name":"Maintain a clean environment","whyImportant":"Clean spaces improve focus and comfort.","habits":[{"name":"Quick daily reset","frequency":"Daily"},{"name":"Weekly deep clean","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','home','male','Home', '{
  "goals":[
    {"name":"Keep home consistently tidy","whyImportant":"Tidiness reduces stress and saves time.","habits":[{"name":"10 minute reset daily","frequency":"Daily"},{"name":"Weekly declutter","frequency":"Weekly"}]},
    {"name":"Upgrade a home area","whyImportant":"Small upgrades improve daily life.","habits":[{"name":"One improvement weekly","frequency":"Weekly"},{"name":"Plan materials weekly","frequency":"Weekly"}]},
    {"name":"Create a calm home routine","whyImportant":"Routine makes home restorative.","habits":[{"name":"Evening reset","frequency":"Daily"},{"name":"Weekend clean","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','home','female','Home', '{
  "goals":[
    {"name":"Create a cozy sanctuary","whyImportant":"A sanctuary supports peace and recovery.","habits":[{"name":"10 minute tidy daily","frequency":"Daily"},{"name":"Declutter weekly","frequency":"Weekly"}]},
    {"name":"Organize with simple systems","whyImportant":"Systems reduce daily friction.","habits":[{"name":"One drawer weekly","frequency":"Weekly"},{"name":"Weekly reset routine","frequency":"Weekly"}]},
    {"name":"Make home beautiful and functional","whyImportant":"Beauty supports motivation.","habits":[{"name":"One small improvement weekly","frequency":"Weekly"},{"name":"Clean one area weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('lifestyle_adventure','home','non_binary','Home', '{
  "goals":[
    {"name":"Create a calm home environment","whyImportant":"Calm spaces improve mood and focus.","habits":[{"name":"Daily 10 minute reset","frequency":"Daily"},{"name":"Weekly declutter","frequency":"Weekly"}]},
    {"name":"Build simple organization systems","whyImportant":"Systems reduce stress.","habits":[{"name":"Organize one area weekly","frequency":"Weekly"},{"name":"Weekly reset routine","frequency":"Weekly"}]},
    {"name":"Keep a clean space","whyImportant":"Clean spaces support comfort.","habits":[{"name":"Quick tidy daily","frequency":"Daily"},{"name":"Weekly clean routine","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- connection_community / family
('connection_community','family','unisex','Family', '{
  "goals":[
    {"name":"Spend quality time with family","whyImportant":"Time together strengthens bonds.","habits":[{"name":"Family meal weekly","frequency":"Weekly"},{"name":"Weekly check in call","frequency":"Weekly"}]},
    {"name":"Improve family communication","whyImportant":"Communication reduces conflict and builds trust.","habits":[{"name":"Active listening daily","frequency":"Daily"},{"name":"Weekly family check in","frequency":"Weekly"}]},
    {"name":"Create family traditions","whyImportant":"Traditions build belonging.","habits":[{"name":"Plan one tradition monthly","frequency":"Weekly"},{"name":"Capture memories weekly","frequency":"Weekly"}]},
    {"name":"Support a family member","whyImportant":"Support builds connection.","habits":[{"name":"Offer help weekly","frequency":"Weekly"},{"name":"Send a kind message weekly","frequency":"Weekly"}]},
    {"name":"Be more present at home","whyImportant":"Presence builds stronger relationships.","habits":[{"name":"Phone free time daily","frequency":"Daily"},{"name":"One shared activity weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','family','male','Family', '{
  "goals":[
    {"name":"Be more present with family","whyImportant":"Presence strengthens trust and connection.","habits":[{"name":"Phone free dinner","frequency":"Daily"},{"name":"Weekly family activity","frequency":"Weekly"}]},
    {"name":"Improve family communication","whyImportant":"Communication reduces stress and conflict.","habits":[{"name":"Listen first daily","frequency":"Daily"},{"name":"Weekly check in","frequency":"Weekly"}]},
    {"name":"Build a family tradition","whyImportant":"Traditions build belonging.","habits":[{"name":"Plan monthly tradition","frequency":"Weekly"},{"name":"Capture memory weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','family','female','Family', '{
  "goals":[
    {"name":"Create more quality family time","whyImportant":"Time together strengthens relationships.","habits":[{"name":"Family meal weekly","frequency":"Weekly"},{"name":"Weekly check in call","frequency":"Weekly"}]},
    {"name":"Improve communication and patience","whyImportant":"Patience builds a calmer home.","habits":[{"name":"Pause before responding","frequency":"Daily"},{"name":"Weekly family check in","frequency":"Weekly"}]},
    {"name":"Start a new family tradition","whyImportant":"Traditions create belonging.","habits":[{"name":"Plan one tradition monthly","frequency":"Weekly"},{"name":"Capture memories weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','family','non_binary','Family', '{
  "goals":[
    {"name":"Deepen family connection","whyImportant":"Connection supports belonging and wellbeing.","habits":[{"name":"Weekly check in","frequency":"Weekly"},{"name":"One shared activity weekly","frequency":"Weekly"}]},
    {"name":"Improve family communication","whyImportant":"Communication builds trust.","habits":[{"name":"Active listening daily","frequency":"Daily"},{"name":"Weekly family check in","frequency":"Weekly"}]},
    {"name":"Be more present at home","whyImportant":"Presence strengthens bonds.","habits":[{"name":"Phone free time daily","frequency":"Daily"},{"name":"Weekly family plan","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- connection_community / friends
('connection_community','friends','unisex','Friends', '{
  "goals":[
    {"name":"Strengthen friendships","whyImportant":"Strong friendships improve happiness.","habits":[{"name":"Reach out to one friend weekly","frequency":"Weekly"},{"name":"Plan one hangout monthly","frequency":"Weekly"}]},
    {"name":"Meet new friends","whyImportant":"New friends expand community.","habits":[{"name":"Attend one community event weekly","frequency":"Weekly"},{"name":"Start one conversation daily","frequency":"Daily"}]},
    {"name":"Be a supportive friend","whyImportant":"Support builds trust and closeness.","habits":[{"name":"Send a kind message weekly","frequency":"Weekly"},{"name":"Check in weekly","frequency":"Weekly"}]},
    {"name":"Create consistent social time","whyImportant":"Consistency keeps relationships alive.","habits":[{"name":"Plan social time weekly","frequency":"Weekly"},{"name":"Follow up on plans","frequency":"Weekly"}]},
    {"name":"Improve social confidence","whyImportant":"Confidence makes connection easier.","habits":[{"name":"Start one conversation daily","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','friends','male','Friends', '{
  "goals":[
    {"name":"Reconnect with friends","whyImportant":"Reconnection strengthens support systems.","habits":[{"name":"Message one friend weekly","frequency":"Weekly"},{"name":"Plan a hangout monthly","frequency":"Weekly"}]},
    {"name":"Build social consistency","whyImportant":"Consistency keeps friendships strong.","habits":[{"name":"Weekly social plan","frequency":"Weekly"},{"name":"Follow up weekly","frequency":"Weekly"}]},
    {"name":"Improve social confidence","whyImportant":"Confidence supports connection.","habits":[{"name":"Start one conversation daily","frequency":"Daily"},{"name":"Attend one event weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','friends','female','Friends', '{
  "goals":[
    {"name":"Deepen close friendships","whyImportant":"Depth improves support and joy.","habits":[{"name":"Reach out weekly","frequency":"Weekly"},{"name":"Plan one hangout monthly","frequency":"Weekly"}]},
    {"name":"Expand your circle","whyImportant":"A wider circle increases community.","habits":[{"name":"Attend one event weekly","frequency":"Weekly"},{"name":"Start one conversation daily","frequency":"Daily"}]},
    {"name":"Be a supportive friend","whyImportant":"Support builds trust.","habits":[{"name":"Check in weekly","frequency":"Weekly"},{"name":"Send a kind note weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','friends','non_binary','Friends', '{
  "goals":[
    {"name":"Strengthen friendships","whyImportant":"Friendship supports wellbeing.","habits":[{"name":"Reach out weekly","frequency":"Weekly"},{"name":"Plan monthly hangout","frequency":"Weekly"}]},
    {"name":"Meet new people","whyImportant":"New people expand community.","habits":[{"name":"Attend weekly event","frequency":"Weekly"},{"name":"Start one conversation daily","frequency":"Daily"}]},
    {"name":"Build social confidence","whyImportant":"Confidence makes connection easier.","habits":[{"name":"Small conversation daily","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- connection_community / community
('connection_community','community','unisex','Community', '{
  "goals":[
    {"name":"Join a community group","whyImportant":"Belonging improves happiness.","habits":[{"name":"Attend one meetup weekly","frequency":"Weekly"},{"name":"Introduce yourself to someone new","frequency":"Weekly"}]},
    {"name":"Volunteer regularly","whyImportant":"Giving back creates meaning.","habits":[{"name":"Volunteer monthly","frequency":"Weekly"},{"name":"Find one cause you care about","frequency":"Weekly"}]},
    {"name":"Build supportive networks","whyImportant":"Networks create opportunities and support.","habits":[{"name":"Weekly networking message","frequency":"Weekly"},{"name":"Attend one event monthly","frequency":"Weekly"}]},
    {"name":"Contribute to your neighborhood","whyImportant":"Contribution builds connection.","habits":[{"name":"Help someone weekly","frequency":"Weekly"},{"name":"Share resources weekly","frequency":"Weekly"}]},
    {"name":"Create a sense of belonging","whyImportant":"Belonging supports mental wellbeing.","habits":[{"name":"Reach out weekly","frequency":"Weekly"},{"name":"Show up consistently","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','community','male','Community', '{
  "goals":[
    {"name":"Join a local group","whyImportant":"Groups build belonging and support.","habits":[{"name":"Attend weekly meetup","frequency":"Weekly"},{"name":"Introduce yourself weekly","frequency":"Weekly"}]},
    {"name":"Volunteer monthly","whyImportant":"Service creates meaning.","habits":[{"name":"Volunteer monthly","frequency":"Weekly"},{"name":"Pick a cause weekly","frequency":"Weekly"}]},
    {"name":"Build a strong network","whyImportant":"Networks create opportunities.","habits":[{"name":"Weekly networking message","frequency":"Weekly"},{"name":"Attend one event monthly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','community','female','Community', '{
  "goals":[
    {"name":"Build community belonging","whyImportant":"Belonging improves wellbeing.","habits":[{"name":"Attend one meetup weekly","frequency":"Weekly"},{"name":"Follow up weekly","frequency":"Weekly"}]},
    {"name":"Volunteer for a cause","whyImportant":"Giving back creates meaning.","habits":[{"name":"Volunteer monthly","frequency":"Weekly"},{"name":"Find one cause weekly","frequency":"Weekly"}]},
    {"name":"Grow supportive networks","whyImportant":"Networks provide support and opportunity.","habits":[{"name":"Reach out weekly","frequency":"Weekly"},{"name":"Attend one event monthly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','community','non_binary','Community', '{
  "goals":[
    {"name":"Join a community group","whyImportant":"Groups support belonging and growth.","habits":[{"name":"Attend weekly meetup","frequency":"Weekly"},{"name":"Introduce yourself weekly","frequency":"Weekly"}]},
    {"name":"Volunteer consistently","whyImportant":"Service builds meaning.","habits":[{"name":"Volunteer monthly","frequency":"Weekly"},{"name":"Pick a cause weekly","frequency":"Weekly"}]},
    {"name":"Build a supportive network","whyImportant":"Networks create support and opportunity.","habits":[{"name":"Message one person weekly","frequency":"Weekly"},{"name":"Attend monthly event","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),

-- connection_community / relationships
('connection_community','relationships','unisex','Relationships', '{
  "goals":[
    {"name":"Improve relationship communication","whyImportant":"Communication builds trust and intimacy.","habits":[{"name":"Weekly check in talk","frequency":"Weekly"},{"name":"Active listening daily","frequency":"Daily"}]},
    {"name":"Build deeper connection","whyImportant":"Connection improves wellbeing.","habits":[{"name":"Quality time weekly","frequency":"Weekly"},{"name":"Daily appreciation","frequency":"Daily"}]},
    {"name":"Create healthier boundaries","whyImportant":"Boundaries reduce stress and conflict.","habits":[{"name":"Name one boundary weekly","frequency":"Weekly"},{"name":"Practice saying no","frequency":"Weekly"}]},
    {"name":"Be more present with partner","whyImportant":"Presence increases intimacy.","habits":[{"name":"Phone free time daily","frequency":"Daily"},{"name":"Weekly date plan","frequency":"Weekly"}]},
    {"name":"Grow relationship trust","whyImportant":"Trust makes relationships safe and strong.","habits":[{"name":"Keep commitments daily","frequency":"Daily"},{"name":"Weekly reflection","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','relationships','male','Relationships', '{
  "goals":[
    {"name":"Improve relationship communication","whyImportant":"Communication strengthens trust.","habits":[{"name":"Weekly check in","frequency":"Weekly"},{"name":"Listen first daily","frequency":"Daily"}]},
    {"name":"Plan consistent quality time","whyImportant":"Time together deepens connection.","habits":[{"name":"Weekly date plan","frequency":"Weekly"},{"name":"Daily appreciation","frequency":"Daily"}]},
    {"name":"Build healthier boundaries","whyImportant":"Boundaries reduce conflict and stress.","habits":[{"name":"Name one boundary weekly","frequency":"Weekly"},{"name":"Practice clear requests","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','relationships','female','Relationships', '{
  "goals":[
    {"name":"Build deeper emotional connection","whyImportant":"Connection improves happiness and stability.","habits":[{"name":"Weekly check in talk","frequency":"Weekly"},{"name":"Daily appreciation","frequency":"Daily"}]},
    {"name":"Improve communication and clarity","whyImportant":"Clarity reduces conflict.","habits":[{"name":"Active listening daily","frequency":"Daily"},{"name":"Weekly relationship talk","frequency":"Weekly"}]},
    {"name":"Create healthier boundaries","whyImportant":"Boundaries protect your energy.","habits":[{"name":"Name one boundary weekly","frequency":"Weekly"},{"name":"Practice saying no weekly","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null),
('connection_community','relationships','non_binary','Relationships', '{
  "goals":[
    {"name":"Improve relationship communication","whyImportant":"Communication builds trust and safety.","habits":[{"name":"Weekly check in","frequency":"Weekly"},{"name":"Active listening daily","frequency":"Daily"}]},
    {"name":"Create consistent quality time","whyImportant":"Quality time deepens connection.","habits":[{"name":"Weekly date plan","frequency":"Weekly"},{"name":"Daily appreciation","frequency":"Daily"}]},
    {"name":"Build healthier boundaries","whyImportant":"Boundaries support respect and calm.","habits":[{"name":"Name one boundary weekly","frequency":"Weekly"},{"name":"Practice clear requests","frequency":"Weekly"}]}
  ]
}'::jsonb, 'seed', null)

on conflict (core_value_id, category_key, gender_key) do update set
  category_label = excluded.category_label,
  recommendations_json = excluded.recommendations_json,
  source = excluded.source,
  created_by = excluded.created_by,
  updated_at = now();

