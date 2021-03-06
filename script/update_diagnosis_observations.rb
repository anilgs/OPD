# voiding the current diagnosis observations and creating new diagnosis observations
# and also creating vitals encounters and their observations
# then change all the diagnosis encounter_type to outpatient diagnosis

start_time = Time.now
puts "Start Time: #{start_time}\n\n"
logger = Logger.new(Rails.root.join("log",'update_diagnosis_observations.log')) #,3,5*1024*1024)
logger.info "Start Time: #{start_time}"
total_saved = 0

primary_diagnosis_concept_id = ConceptName.find_by_name('PRIMARY DIAGNOSIS').concept_id
detailed_primary_diagnosis_concept_id = ConceptName.find_by_name('DETAILED PRIMARY DIAGNOSIS').concept_id
specific_primary_diagnosis_concept_id = ConceptName.find_by_name('SPECIFIC PRIMARY DIAGNOSIS').concept_id

weight_concept_id = ConceptName.find_by_name('WEIGHT').concept_id
vitals_encounter_type_id = EncounterType.find_by_name('VITALS').encounter_type_id

diagnosis_obs = Observation.find_by_sql(" SELECT o.*, e.provider_id, e.form_id, e.encounter_datetime FROM encounter e
                                            LEFT JOIN obs o ON o.encounter_id = e.encounter_id
                                          WHERE e.encounter_type = 41
                                          AND e.voided = 0
                                          AND o.voided = 0")

diagnosis_obs.each do |aDiagnosis|
  if aDiagnosis.concept_id != weight_concept_id
     value_coded_name_id = ConceptName.find_by_sql("SELECT concept_name_id FROM concept_name WHERE concept_id = #{aDiagnosis.concept_id}").map{|c| c.concept_name_id}
    
    #create the primary diagnosis 
    obs = {}
    obs[:concept_id] = primary_diagnosis_concept_id 
    obs[:value_coded] = aDiagnosis.concept_id
    obs[:value_coded_name_id] = value_coded_name_id.first
    obs[:encounter_id] = aDiagnosis.encounter_id
    obs[:obs_datetime] = aDiagnosis.obs_datetime
    obs[:person_id] = aDiagnosis.person_id  
    obs[:location_id] = aDiagnosis.location_id
    obs[:creator] = aDiagnosis.creator
    Observation.create(obs)
    total_saved += 1
    logger.info "Total saved => #{total_saved} concept => #{obs[:concept_id]} value_coded => #{obs[:value_coded]} encounter => #{obs[:encounter_id]}"
  
    if aDiagnosis.value_coded
      #create the detailed_primary_diagnosis
      obs = {}
      obs[:concept_id] = detailed_primary_diagnosis_concept_id
      obs[:value_coded] = aDiagnosis.value_coded
      obs[:value_coded_name_id] = aDiagnosis.value_coded_name_id 
      obs[:encounter_id] = aDiagnosis.encounter_id
      obs[:obs_datetime] = aDiagnosis.obs_datetime
      obs[:person_id] = aDiagnosis.person_id  
      obs[:location_id] = aDiagnosis.location_id
      obs[:creator] = aDiagnosis.creator
      Observation.create(obs)
      total_saved += 1
      logger.info "Total saved => #{total_saved} concept => #{obs[:concept_id]} value_coded => #{obs[:value_coded]} encounter => #{obs[:encounter_id]}"
    else
      if aDiagnosis.value_text
        #create the specific_primary_diagnosis
        obs = {}
        obs[:concept_id] = specific_primary_diagnosis_concept_id 
        obs[:value_text] = aDiagnosis.value_text
        obs[:encounter_id] = aDiagnosis.encounter_id
        obs[:obs_datetime] = aDiagnosis.obs_datetime
        obs[:person_id] = aDiagnosis.person_id  
        obs[:location_id] = aDiagnosis.location_id
        obs[:creator] = aDiagnosis.creator
        Observation.create(obs)
        total_saved += 1
        logger.info "Total saved => #{total_saved} concept => #{obs[:concept_id]} value_text => #{obs[:value_text]} encounter => #{obs[:encounter_id]}"
      end
    end
 
  else
    #create vitals encounter
    encounter = Encounter.new()
    encounter.encounter_type = vitals_encounter_type_id
    encounter.form_id = aDiagnosis.form_id
    encounter.provider_id = aDiagnosis.provider_id
    encounter.encounter_datetime = aDiagnosis.encounter_datetime
    encounter.patient_id = aDiagnosis.person_id
    encounter.location_id = aDiagnosis.location_id
    encounter.creator = aDiagnosis.creator
    encounter.save

    if encounter.save
      #create vitals obs
      obs = {}
      obs[:concept_id] = weight_concept_id
      obs[:value_numeric] = aDiagnosis.value_numeric 
      obs[:encounter_id] = encounter.encounter_id
      obs[:obs_datetime] = encounter.encounter_datetime
      obs[:person_id] = aDiagnosis.person_id  
      obs[:location_id] = aDiagnosis.location_id
      obs[:creator] = aDiagnosis.creator
      Observation.create(obs)
      total_saved += 1
      logger.info "Total saved => #{total_saved} concept => #{obs[:concept_id]} value_numeric => #{obs[:value_numeric]} encounter => #{obs[:encounter_id]}"
      #create obs diagnosis
      if aDiagnosis.value_coded
        #create the primary diagnosis
        obs = {}
        obs[:concept_id] = primary_diagnosis_concept_id
        obs[:value_coded] = aDiagnosis.value_coded
        #obs[:value_coded_name_id] =  aDiagnosis.value_coded_name_id
        obs[:encounter_id] = aDiagnosis.encounter_id
        obs[:obs_datetime] = aDiagnosis.obs_datetime
        obs[:person_id] = aDiagnosis.person_id  
        obs[:location_id] = aDiagnosis.location_id
        obs[:creator] = aDiagnosis.creator
        Observation.create(obs)
        total_saved += 1
        logger.info "Total saved => #{total_saved} concept => #{obs[:concept_id]} value_coded => #{obs[:value_coded]} encounter => #{obs[:encounter_id]}"
      else
        if aDiagnosis.value_text
          #create the specific_primary_diagnosis
          obs = {}
          obs[:concept_id] = specific_primary_diagnosis_concept_id
          obs[:value_text] = aDiagnosis.value_text 
          obs[:encounter_id] = aDiagnosis.encounter_id
          obs[:obs_datetime] = aDiagnosis.obs_datetime
          obs[:person_id] = aDiagnosis.person_id  
          obs[:location_id] = aDiagnosis.location_id
          obs[:creator] = aDiagnosis.creator
          Observation.create(obs)
          total_saved += 1
          logger.info "Total saved => #{total_saved} concept => #{obs[:concept_id]} value_text => #{obs[:value_text]} encounter => #{obs[:encounter_id]}"
        end
      end
     end
  end
  #void the diagnosis
  aDiagnosis.voided = 1
  aDiagnosis.date_created = Date.today
  aDiagnosis.void_reason = "Migration"
  aDiagnosis.save

end

#upadate the diagnosis encounter_type to outpatient diagnosis encounter_type
#
outpatient_diagnosis_encounter_type_id = EncounterType.find_by_name('OUTPATIENT DIAGNOSIS').encounter_type_id
diagnosis_encounter_type = EncounterType.find_by_name('DIAGNOSIS').encounter_type_id

#pull out all diagnosis encounters that are not voided
diagnosis_encounters = Encounter.find_by_sql(" SELECT * FROM encounter
                                               WHERE encounter_type = #{diagnosis_encounter_type} 
                                               AND voided = 0 ")

diagnosis_encounters.each do |aDiagnosis_encounter|
  #change the diagnosis encounter_type_id to outpatient_diagnosis encounter_type_id
  aDiagnosis_encounter.encounter_type = outpatient_diagnosis_encounter_type_id
  aDiagnosis_encounter.date_created = Date.today
  aDiagnosis_encounter.save
end

end_time = Time.now

logger.info "End Time: #{end_time}"
puts "Start Time: #{end_time}\n\n"
logger.info "Total saved: #{total_saved}"
logger.info "It took : #{end_time - start_time}"
logger.info "Completed successfully !!\n\n"
