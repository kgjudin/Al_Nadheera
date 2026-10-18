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
      -- 1. Add location columns to employees table
      ALTER TABLE public.employees
      ADD COLUMN IF NOT EXISTS last_latitude DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS last_longitude DOUBLE PRECISION,
      ADD COLUMN IF NOT EXISTS last_location_address TEXT,
      ADD COLUMN IF NOT EXISTS last_location_updated_at TIMESTAMPTZ;

      -- 2. Create employee_location_logs table for location history
      CREATE TABLE IF NOT EXISTS public.employee_location_logs (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          employee_id UUID REFERENCES public.employees(id) ON DELETE CASCADE,
          latitude DOUBLE PRECISION NOT NULL,
          longitude DOUBLE PRECISION NOT NULL,
          address TEXT,
          accuracy DOUBLE PRECISION,
          recorded_at TIMESTAMPTZ DEFAULT NOW(),
          created_at TIMESTAMPTZ DEFAULT NOW()
      );

      ALTER TABLE public.employee_location_logs ENABLE ROW LEVEL SECURITY;

      DROP POLICY IF EXISTS "Allow authenticated full access to employee_location_logs" ON public.employee_location_logs;
      CREATE POLICY "Allow authenticated full access to employee_location_logs" ON public.employee_location_logs FOR ALL TO authenticated USING (true) WITH CHECK (true);

      DROP POLICY IF EXISTS "Allow anon full access to employee_location_logs" ON public.employee_location_logs;
      CREATE POLICY "Allow anon full access to employee_location_logs" ON public.employee_location_logs FOR ALL TO anon USING (true) WITH CHECK (true);

      NOTIFY pgrst, 'reload schema';
    `;

    await client.query(sql);
    console.log('Successfully added location tracking columns and table!');
  } catch (err) {
    console.error('Error applying migration:', err);
  } finally {
    await client.end();
  }
}

run();
