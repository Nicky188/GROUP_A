-- ============================================================
-- SUPABASE SETUP SQL — Student Assistant Application System
-- TPG316C Group Assignment
-- ============================================================
-- Run all of this in your Supabase SQL Editor (in order).
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. PROFILES TABLE
-- Stores extended user information linked to Supabase Auth.
-- Every user who logs in needs a row here.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email       TEXT NOT NULL,
    full_name   TEXT NOT NULL DEFAULT '',
    student_number TEXT NOT NULL DEFAULT '',
    role        TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'admin')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Allow users to read and update their own profile
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- Admins can read all profiles
CREATE POLICY "Admins can view all profiles"
    ON public.profiles FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ────────────────────────────────────────────────────────────
-- 2. APPLICATIONS TABLE
-- Stores all Student Assistant applications.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.applications (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id           UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_name         TEXT NOT NULL,
    student_number       TEXT NOT NULL,
    year_of_study        INT NOT NULL CHECK (year_of_study BETWEEN 1 AND 3),
    module1_level        TEXT NOT NULL,
    module1_code         TEXT NOT NULL,
    has_second_module    BOOLEAN NOT NULL DEFAULT FALSE,
    module2_level        TEXT,
    module2_code         TEXT,
    eligibility_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    document_url         TEXT,
    status               TEXT NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-update updated_at on changes
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER applications_updated_at
    BEFORE UPDATE ON public.applications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ────────────────────────────────────────────────────────────
-- 3. ROW LEVEL SECURITY FOR APPLICATIONS
-- Students can only see/edit their own. Admins see all.
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;

-- Students: read their own applications
CREATE POLICY "Students can view own applications"
    ON public.applications FOR SELECT
    USING (auth.uid() = student_id);

-- Students: create an application (only one allowed — enforced in app)
CREATE POLICY "Students can create applications"
    ON public.applications FOR INSERT
    WITH CHECK (auth.uid() = student_id);

-- Students: update their own pending applications
CREATE POLICY "Students can update own pending applications"
    ON public.applications FOR UPDATE
    USING (auth.uid() = student_id AND status = 'pending');

-- Students: delete their own pending applications
CREATE POLICY "Students can delete own pending applications"
    ON public.applications FOR DELETE
    USING (auth.uid() = student_id AND status = 'pending');

-- Admins: read all applications
CREATE POLICY "Admins can view all applications"
    ON public.applications FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Admins: update any application (approve/reject/edit)
CREATE POLICY "Admins can update all applications"
    ON public.applications FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Admins: delete any application
CREATE POLICY "Admins can delete all applications"
    ON public.applications FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- ────────────────────────────────────────────────────────────
-- 4. STORAGE BUCKET for supporting documents
-- ────────────────────────────────────────────────────────────
-- Run this in the Supabase Dashboard → Storage → New Bucket:
--   Name: application-documents
--   Public: true (so documents can be viewed)
--
-- Or via SQL:
INSERT INTO storage.buckets (id, name, public)
VALUES ('application-documents', 'application-documents', true)
ON CONFLICT DO NOTHING;

-- Allow authenticated users to upload documents
CREATE POLICY "Authenticated users can upload documents"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'application-documents'
        AND auth.role() = 'authenticated'
    );

-- Allow authenticated users to read documents
CREATE POLICY "Authenticated users can read documents"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'application-documents'
        AND auth.role() = 'authenticated'
    );

-- ────────────────────────────────────────────────────────────
-- 5. AUTO-CREATE PROFILE ON SIGNUP
-- Trigger that creates a profile row automatically when a new
-- user registers via Supabase Auth.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, student_number, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'student_number', ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'student')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ────────────────────────────────────────────────────────────
-- 6. SEED: CREATE AN ADMIN USER MANUALLY
-- After registering an admin through Supabase Auth Dashboard,
-- update their role manually with this:
-- ────────────────────────────────────────────────────────────
-- UPDATE public.profiles
-- SET role = 'admin'
-- WHERE email = 'admin@cut.ac.za';

-- ────────────────────────────────────────────────────────────
-- 7. SEED: SAMPLE TEST DATA (optional — for development only)
-- ────────────────────────────────────────────────────────────
-- Insert sample data only AFTER creating real users via Auth.
-- Replace the UUIDs with actual user IDs from auth.users.
