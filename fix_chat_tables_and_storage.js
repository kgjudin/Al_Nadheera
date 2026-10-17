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
      -- 1. Ensure chat_messages columns exist
      ALTER TABLE public.chat_messages
        ADD COLUMN IF NOT EXISTS reply_to_id UUID REFERENCES public.chat_messages(id) ON DELETE SET NULL,
        ADD COLUMN IF NOT EXISTS reply_to_text TEXT,
        ADD COLUMN IF NOT EXISTS reply_to_sender_name TEXT,
        ADD COLUMN IF NOT EXISTS file_name TEXT,
        ADD COLUMN IF NOT EXISTS file_size BIGINT;

      -- 2. Ensure chat-media bucket is public
      UPDATE storage.buckets SET public = true WHERE id = 'chat-media';
      INSERT INTO storage.buckets (id, name, public) 
      VALUES ('chat-media', 'chat-media', true) 
      ON CONFLICT (id) DO UPDATE SET public = true;

      -- 3. Storage policies for chat-media
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_policies 
          WHERE tablename = 'objects' 
            AND schemaname = 'storage' 
            AND policyname = 'Public chat media select'
        ) THEN
          CREATE POLICY "Public chat media select" ON storage.objects 
            FOR SELECT TO public USING (bucket_id = 'chat-media');
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM pg_policies 
          WHERE tablename = 'objects' 
            AND schemaname = 'storage' 
            AND policyname = 'Allow chat media upload'
        ) THEN
          CREATE POLICY "Allow chat media upload" ON storage.objects 
            FOR INSERT TO authenticated WITH CHECK (bucket_id = 'chat-media');
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM pg_policies 
          WHERE tablename = 'objects' 
            AND schemaname = 'storage' 
            AND policyname = 'Allow public chat media upload'
        ) THEN
          CREATE POLICY "Allow public chat media upload" ON storage.objects 
            FOR INSERT TO public WITH CHECK (bucket_id = 'chat-media');
        END IF;
      END $$;

      -- 4. Reload PostgREST schema cache
      NOTIFY pgrst, 'reload schema';
    `;

    await client.query(sql);
    console.log('Migration successfully executed!');
  } catch (err) {
    console.error('Migration failed:', err);
  } finally {
    await client.end();
  }
}

run();
