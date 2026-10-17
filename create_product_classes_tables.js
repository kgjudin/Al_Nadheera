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
      -- 1. Create product_classes table
      CREATE TABLE IF NOT EXISTS public.product_classes (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          name TEXT NOT NULL UNIQUE,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
      );

      ALTER TABLE public.product_classes ENABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS "Allow authenticated full access to product_classes" ON public.product_classes;
      CREATE POLICY "Allow authenticated full access to product_classes" ON public.product_classes FOR ALL TO authenticated USING (true) WITH CHECK (true);
      DROP POLICY IF EXISTS "Allow anon full access to product_classes" ON public.product_classes;
      CREATE POLICY "Allow anon full access to product_classes" ON public.product_classes FOR ALL TO anon USING (true) WITH CHECK (true);

      -- 2. Create product_submodules table
      CREATE TABLE IF NOT EXISTS public.product_submodules (
          id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          class_id UUID REFERENCES public.product_classes(id) ON DELETE CASCADE,
          class_name TEXT NOT NULL,
          name TEXT NOT NULL,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW(),
          UNIQUE(class_name, name)
      );

      ALTER TABLE public.product_submodules ENABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS "Allow authenticated full access to product_submodules" ON public.product_submodules;
      CREATE POLICY "Allow authenticated full access to product_submodules" ON public.product_submodules FOR ALL TO authenticated USING (true) WITH CHECK (true);
      DROP POLICY IF EXISTS "Allow anon full access to product_submodules" ON public.product_submodules;
      CREATE POLICY "Allow anon full access to product_submodules" ON public.product_submodules FOR ALL TO anon USING (true) WITH CHECK (true);

      -- 3. Add class and submodule columns to products table
      ALTER TABLE public.products ADD COLUMN IF NOT EXISTS class_name TEXT;
      ALTER TABLE public.products ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES public.product_classes(id) ON DELETE SET NULL;
      ALTER TABLE public.products ADD COLUMN IF NOT EXISTS submodule_name TEXT;
      ALTER TABLE public.products ADD COLUMN IF NOT EXISTS submodule_id UUID REFERENCES public.product_submodules(id) ON DELETE SET NULL;

      -- 4. Insert default Class & Sub-modules if not existing (e.g. CLASS I PIPE WORK)
      INSERT INTO public.product_classes (name) VALUES 
        ('CLASS I PIPE WORK'),
        ('CLASS J PIPEWORK - FITTINGS AND VALVES'),
        ('CLASS K MANHOLES AND PIPEWORK ANCILLARIES'),
        ('CLASS L PIPEWORK - SUPPORTS & PROTECTION')
      ON CONFLICT (name) DO NOTHING;

      -- Insert submodules for CLASS I PIPE WORK
      INSERT INTO public.product_submodules (class_name, name) VALUES 
        ('CLASS I PIPE WORK', 'Nominal bore'),
        ('CLASS I PIPE WORK', 'Pipe'),
        ('CLASS I PIPE WORK', 'Fittings'),
        ('CLASS J PIPEWORK - FITTINGS AND VALVES', 'Fittings'),
        ('CLASS J PIPEWORK - FITTINGS AND VALVES', 'Valves'),
        ('CLASS K MANHOLES AND PIPEWORK ANCILLARIES', 'Manholes'),
        ('CLASS K MANHOLES AND PIPEWORK ANCILLARIES', 'Ancillaries'),
        ('CLASS L PIPEWORK - SUPPORTS & PROTECTION', 'Supports'),
        ('CLASS L PIPEWORK - SUPPORTS & PROTECTION', 'Protection')
      ON CONFLICT (class_name, name) DO NOTHING;

      -- Update class_id on submodules
      UPDATE public.product_submodules sm
      SET class_id = c.id
      FROM public.product_classes c
      WHERE sm.class_name = c.name AND sm.class_id IS NULL;

      -- 5. Force reload PostgREST schema cache
      NOTIFY pgrst, 'reload schema';
    `;

    await client.query(sql);
    console.log('Migration completed successfully! product_classes and product_submodules created.');

    const classesRes = await client.query('SELECT * FROM public.product_classes ORDER BY name');
    console.log('Current product_classes count:', classesRes.rowCount);

    const submodulesRes = await client.query('SELECT * FROM public.product_submodules ORDER BY class_name, name');
    console.log('Current product_submodules count:', submodulesRes.rowCount);
  } catch (err) {
    console.error('Migration error:', err);
  } finally {
    await client.end();
  }
}

run();
