# Install Map

The install shape is intentionally simple:

1. Identify the target disk and partition plan.
2. Create the filesystem layout you want Praxis to live on.
3. Mount the target filesystems.
4. Seed the Praxis base system onto the target root.
5. Install or register the Praxis boot path.
6. Verify the target with `praxis-target-check`.
7. Reboot into the system you built.

Use `praxis-help install` in the live image for the matching command flow.
