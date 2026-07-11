--@ module=true

local DESCRIPTIONS = {
    physical_attribute={
        STRENGTH='Muscular power for carrying, melee force, and movement.',
        AGILITY='Improves fast movement and many physical skills.',
        TOUGHNESS='Increases the time required to suffocate.',
        ENDURANCE='Slows exhaustion and speeds tiredness recovery.',
        RECUPERATION='Rate of healing and recovery from injury.',
        DISEASE_RESISTANCE='Reduces susceptible syndrome effects and wound infection.',
    },
    mental_attribute={
        ANALYTICAL_ABILITY='Reasoning and problem-solving ability.',
        FOCUS='Ability to concentrate on a task.',
        WILLPOWER='With high Endurance, prevents collapse from exhaustion.',
        CREATIVITY='Capacity for invention and creative work.',
        INTUITION='Instinctive judgment and insight.',
        PATIENCE='Tolerance for waiting and repetition.',
        MEMORY='Ability to retain information and knowledge.',
        LINGUISTIC_ABILITY='Facility with language and communication.',
        SPATIAL_SENSE='Sense of spatial relationships and surrounding space.',
        MUSICALITY='Sense of music and musical performance.',
        KINESTHETIC_SENSE='Awareness of body movement and coordination.',
        EMPATHY="Ability to understand others' feelings.",
        SOCIAL_AWARENESS='Ability to read social cues and relationships.',
    },
    trait={
        LOVE_PROPENSITY='Tendency to form loving attachments.',
        HATE_PROPENSITY='Tendency to feel hatred toward others.',
        ENVY_PROPENSITY='Tendency to feel jealousy of others.',
        ANGER_PROPENSITY='Tendency to become angry.',
        ANXIETY_PROPENSITY='Tendency to worry and feel anxious.',
        LUST='Tendency toward sexual desire.',
        STRESS_VULNERABILITY='Sensitivity to stress and upsetting events.',
        GREED='Desire for wealth and valuable possessions.',
        CHEER_PROPENSITY='Tendency toward cheerfulness and good mood.',
        DEPRESSION_PROPENSITY='Tendency toward sadness and depression.',
        IMMODERATION='Tendency toward excess and overindulgence.',
        VIOLENT='Enjoyment of violent or physical confrontation.',
        PERSEVERANCE='Tendency to persist despite difficulty.',
        WASTEFULNESS='Tendency to waste resources, time, and effort.',
        DISCORD='Tendency to prefer discord over harmony.',
        FRIENDLINESS='Tendency to seek friendly social contact.',
        POLITENESS='Tendency to follow social courtesies.',
        DISDAIN_ADVICE="Tendency to reject advice and rely on one's own counsel.",
        BRAVERY='Willingness to face danger and confrontation.',
        CONFIDENCE="Belief in one's own ability and judgment.",
        VANITY="Concern with one's own appearance and worth.",
        AMBITION='Drive to achieve status or accomplishment.',
        GRATITUDE='Tendency to appreciate help from others.',
        IMMODESTY='Tendency to present oneself extravagantly.',
        HUMOR='Tendency to enjoy or create humor.',
        VENGEFUL='Tendency to seek revenge for wrongs.',
        PRIDE='Concern with dignity and personal accomplishment.',
        CRUELTY="Tendency to disregard or enjoy others' suffering.",
        SINGLEMINDED='Tendency to pursue one goal without distraction.',
        HOPEFUL='Expectation that outcomes will improve.',
        CURIOUS='Desire to learn and investigate the world.',
        BASHFUL='Tendency to feel shy or socially hesitant.',
        PRIVACY='Need to keep personal matters private.',
        PERFECTIONIST='Desire for precision and flawlessness.',
        CLOSEMINDED='Resistance to unfamiliar ideas and customs.',
        TOLERANT='Acceptance of differences in others.',
        EMOTIONALLY_OBSESSIVE='Tendency to be ruled by strong emotions.',
        SWAYED_BY_EMOTIONS='Tendency to make decisions emotionally.',
        ALTRUISM='Willingness to help others without reward.',
        DUTIFULNESS='Sense of responsibility and obligation.',
        THOUGHTLESSNESS='Tendency to act without considering consequences.',
        ORDERLINESS='Preference for order, routine, and organization.',
        TRUST="Willingness to rely on others' intentions.",
        GREGARIOUSNESS='Desire for company and social activity.',
        ASSERTIVENESS='Willingness to speak up and take charge.',
        ACTIVITY_LEVEL='Preference for being active and busy.',
        EXCITEMENT_SEEKING='Desire for novelty, risk, and stimulation.',
        IMAGINATION='Tendency toward fantasy and inventive thought.',
        ABSTRACT_INCLINED='Interest in abstract ideas over practical detail.',
        ART_INCLINED='Sensitivity to art and natural beauty.',
    },
}

---@param kind SoulSearchStatKind
---@param key string
---@return string
function get_tooltip(kind, key)
    local description = DESCRIPTIONS[kind] and DESCRIPTIONS[kind][key]
    if description then return description end
    if kind == 'trait' then
        return 'A personality trait that shapes behavior and social interaction.'
    end
    return 'An attribute that affects performance in related tasks.'
end
