-- Add photo, receipt, and colorway fields to footwear_items
alter table public.footwear_items
    add column if not exists colorway text not null default '',
    add column if not exists photo_filename text,
    add column if not exists receipt_photo_filename text;
