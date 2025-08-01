//GOOD CODE

upload_options[ 'unique_filename'] = false;

if (resource_info[ 'image_metadata'][ 'Keywords'] && resource_info[ 'image_metadata'][ 'Subject']) {
    let keywordsArray = resource_info[ 'image_metadata'][ 'Keywords'].split(',');
    let subjectArray = resource_info[ 'image_metadata'][ 'Subject'].split(',');
    let keywordsSubject = keywordsArray.concat(subjectArray.filter((item) => keywordsArray.indexOf(item) < 0));
    upload_options[ 'tags'] = keywordsSubject;
} else if (resource_info[ 'image_metadata'][ 'Keywords']) {
    upload_options[ 'tags'] = resource_info[ 'image_metadata'][ 'Keywords'];
} else if (resource_info[ 'image_metadata'][ 'Subject']) {
    upload_options[ 'tags'] = resource_info[ 'image_metadata'][ 'Subject'];
} 

if (resource_info['image_metadata']['Description']) {
upload_options['context']='alt='+resource_info['image_metadata']['Description'];
}

let metadata =
[{
'copyright_notice':resource_info['image_metadata']['CopyrightNotice'],
'artist':resource_info['image_metadata']['Artist'],
'author':resource_info['image_metadata']['ImageCreatorName']
}];
function nonNullValues(obj) {
return Object.fromEntries(
Object.entries(obj).filter(([key, value]) => value !== null)
)
};
const result = metadata.map(nonNullValues);
let keysValues = "";
for (let [key, value] of Object.entries(result[0])) {
keysValues += key+"="+value+"|";
};
keysValues = keysValues.replace(/\|$/, '');
upload_options['metadata']=keysValues;