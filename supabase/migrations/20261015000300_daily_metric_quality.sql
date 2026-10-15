-- Broad physical-domain checks catch unit mistakes without implying clinical thresholds.
alter table public.daily_metric_summaries add constraint daily_metric_value_domain check (
    (metric_kind in ('heart_rate', 'resting_heart_rate', 'hrv_sdnn',
                     'respiratory_rate', 'vo2_max') and value > 0)
    or (metric_kind = 'oxygen_saturation' and value between 0 and 1)
    or (metric_kind in ('sleep_duration', 'steps', 'active_energy',
                        'exercise_duration') and value >= 0)
    or metric_kind = 'wrist_temperature_deviation'
);
