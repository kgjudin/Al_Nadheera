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
      -- Add B2B Quotation and Document Designer columns to invoices table
      ALTER TABLE public.invoices 
        ADD COLUMN IF NOT EXISTS document_type TEXT DEFAULT 'B2B',
        ADD COLUMN IF NOT EXISTS subject TEXT,
        ADD COLUMN IF NOT EXISTS salutation TEXT,
        ADD COLUMN IF NOT EXISTS intro_text TEXT,
        ADD COLUMN IF NOT EXISTS table_header_title TEXT,
        ADD COLUMN IF NOT EXISTS source_config JSONB;

      -- Add item_class to invoice_items table for BOQ classes (e.g. J, K, L)
      ALTER TABLE public.invoice_items
        ADD COLUMN IF NOT EXISTS item_class TEXT;

      -- Reload Supabase PostgREST schema cache
      NOTIFY pgrst, 'reload schema';
    `;

    await client.query(sql);
    console.log('Successfully added B2B columns to invoices and invoice_items!');
    console.log('PostgREST schema cache reloaded.');
  } catch (err) {
    console.error('Error running migration:', err);
  } finally {
    await client.end();
  }
}

run();
