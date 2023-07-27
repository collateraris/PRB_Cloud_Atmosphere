using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SunMovement : MonoBehaviour
{
    [HideInInspector]
    public GameObject sun;
    [HideInInspector]
    public Light sunLight;

    [Range(0, 24)]
    public float timeOfDay = 12;

    public float secondsPerMinute = 60;
    [HideInInspector]
    public float secondsPerHour;
    [HideInInspector]
    public float secondsPerDay;

    public float timeMultiplier = 1;

    private Vector3 prevLocalEulerAngles;

    void Start()
    {
        sun = gameObject;
        sunLight = gameObject.GetComponent<Light>();

        prevLocalEulerAngles = new Vector3(0, 0, 0);

        //secondsPerHour = secondsPerMinute * 60;
        //secondsPerDay = secondsPerHour * 24;
    }

    // Update is called once per frame
    void Update()
    {
        SunUpdate();
    }

    private float DayLength = 0.1f;
    private float _rotationSpeed;

    private bool bRotateByUser = true;

    public void SunUpdate()
    {
        //30,-30,0 = sunrise
        //90,-30,0 = High noon
        //180,-30,0 = sunset
        //-90,-30,0 = Midnight

        //Keyboard commands

        UpdateBaseInput();
    }

    private void UpdateBaseInput()
    { //returns the basic values, if it's 0 than it's not active.

        float direction = 1;

        if (Input.GetKey(KeyCode.M))
        {
            bRotateByUser = !bRotateByUser;
        }

        if (Input.GetKey(KeyCode.Q))
        {
            direction = -1;
            if (bRotateByUser)
            {
                _rotationSpeed = direction * Time.deltaTime / DayLength;
                transform.Rotate(0, _rotationSpeed, 0);
            }
        }
        if (Input.GetKey(KeyCode.E))
        {
            direction = 1;
            if (bRotateByUser)
            {
                _rotationSpeed = direction * Time.deltaTime / DayLength;
                transform.Rotate(0, _rotationSpeed, 0);
            }
        }

        if (Input.GetKey(KeyCode.R))
        {
            direction = 1;
            if (bRotateByUser)
            {
                _rotationSpeed = direction * Time.deltaTime / DayLength;
                transform.Rotate(_rotationSpeed, 0, 0);
            }
        }
        if (Input.GetKey(KeyCode.F))
        {
            direction = -1;
            if (bRotateByUser)
            {
                _rotationSpeed = direction * Time.deltaTime / DayLength;
                transform.Rotate(_rotationSpeed, 0, 0);
            }
        }

        if (!bRotateByUser)
        {
            _rotationSpeed = Time.deltaTime / DayLength;
            transform.Rotate(0, _rotationSpeed, 0);
        }
    }
}
