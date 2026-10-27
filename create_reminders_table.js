const { Client } = require('pg');

const client = new Client({
  host: 'aws-0-ap-southeast-1.pooler.supabase.com',
  port: 6543,
  user: 'postgres.iahwyfbkdmppgmbhteyt',
  password: 'Jd@9746521953',
  database: 'postgres',
});

async function run() {
  try {
    await client.connect();
    console.log('Connected to Supabase PostgreSQL...');

    const sql = `
      -- 1. Create reminders table
      CREATE TABLE IF NOT EXISTS public.reminders (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          title TEXT NOT NULL,
          description TEXT,
          due_date TIMESTAMPTZ NOT NULL,
          category TEXT NOT NULL DEFAULT 'General',
          priority TEXT NOT NULL DEFAULT 'Medium',
          status TEXT NOT NULL DEFAULT 'Pending',
          employee_id UUID REFERENCES public.employees(id) ON DELETE SET NULL,
          employee_name TEXT,
          is_for_self BOOLEAN DEFAULT FALSE,
          target_role TEXT DEFAULT 'Super Admin',
          created_by UUID,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
      );

      ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS "Allow authenticated full access to reminders" ON public.reminders;
      CREATE POLICY "Allow authenticated full access to reminders" ON public.reminders FOR ALL TO authenticated USING (true) WITH CHECK (true);
      DROP POLICY IF EXISTS "Allow anon full access to reminders" ON public.reminders;
      CREATE POLICY "Allow anon full access to reminders" ON public.reminders FOR ALL TO anon USING (true) WITH CHECK (true);

      -- 2. Indexes
      CREATE INDEX IF NOT EXISTS idx_reminders_due_date ON public.reminders(due_date);
      CREATE INDEX IF NOT EXISTS idx_reminders_employee_id ON public.reminders(employee_id);
      CREATE INDEX IF NOT EXISTS idx_reminders_status ON public.reminders(status);
      CREATE INDEX IF NOT EXISTS idx_reminders_category ON public.reminders(category);
    `;

    await client.query(sql);
    console.log('Reminders table and indexes created successfully!');
  } catch (err) {
    console.error('Error creating reminders table:', err);
  } finally {
    await client.end();
  }
}

run();
