
create policy "Staff read patient files" on storage.objects for select to authenticated
  using (bucket_id = 'patient-files' and public.staff_can(auth.uid(), 'files'));
create policy "Staff upload patient files" on storage.objects for insert to authenticated
  with check (bucket_id = 'patient-files' and public.staff_can(auth.uid(), 'files'));
create policy "Staff delete patient files" on storage.objects for delete to authenticated
  using (bucket_id = 'patient-files' and public.staff_can(auth.uid(), 'files'));
